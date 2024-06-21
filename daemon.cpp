#include <thread>

#include <boost/process.hpp>
#include <boost/log/core.hpp>
#include <boost/log/trivial.hpp>
#include <boost/log/expressions.hpp>

#include "aktualizr-lite/api.h"

#define LOG_INFO    BOOST_LOG_TRIVIAL(info)
#define LOG_WARNING BOOST_LOG_TRIVIAL(warning)
#define LOG_ERROR   BOOST_LOG_TRIVIAL(error)

static void reboot(const std::string &reboot_cmd) {
  LOG_INFO << "Device is going to reboot with " << reboot_cmd;
  if (setuid(0) != 0) {
    LOG_ERROR << "Failed to set/verify a root user so cannot reboot system programmatically";
  } else {
    sync();
    if (std::system(reboot_cmd.c_str()) == 0) {
      exit(0);
    }
    LOG_ERROR << "Failed to execute the reboot command";
  }
  exit(1);
}

static std::string get_reboot_cmd(const AkliteClient &client) {
  auto reboot_cmd = client.GetConfig().get("bootloader.reboot_command", "");
  // boost property_tree will include surrounding quotes which we need to
  // strip:
  if (reboot_cmd.front() == '"') {
    reboot_cmd.erase(0, 1);
  }
  if (reboot_cmd.back() == '"') {
    reboot_cmd.erase(reboot_cmd.size() - 1);
  }

  return reboot_cmd;
}

int cmd_daemon(std::string local_repo_path) {
  boost::log::core::get()->set_filter(boost::log::trivial::severity >= boost::log::trivial::info);
  bool is_local_update{false};
  LocalUpdateSource local_update_source;

  std::vector<boost::filesystem::path> cfg_dirs;
  auto env{boost::this_process::environment()};
  if (env.end() != env.find("AKLITE_CONFIG_DIR")) {
    cfg_dirs.emplace_back(env.get("AKLITE_CONFIG_DIR"));
  } else {
    cfg_dirs = AkliteClient::CONFIG_DIRS;
  }

  if (!local_repo_path.empty()) {
    local_update_source = {
      local_repo_path + "/tuf",
      local_repo_path + "/ostree_repo",
      local_repo_path + "/apps"
    };
    is_local_update = true;
    LOG_INFO << "Offline mode. Updates path=" << local_repo_path;
  } else {
    LOG_INFO << "Online mode";
  }

  std::unique_ptr<AkliteClient> client;
  try {
    client = std::make_unique<AkliteClient>(cfg_dirs);
  } catch (const std::exception& exc) {
    LOG_ERROR << "Failed to initialize the client: " << exc.what();
    return EXIT_FAILURE;
  }

  auto interval = client->GetConfig().get("uptane.polling_sec", 600);
  auto reboot_cmd = get_reboot_cmd(*client);

  if (access(reboot_cmd.c_str(), X_OK) != 0) {
    LOG_ERROR << "Reboot command: " << reboot_cmd << " is not executable";
    return EXIT_FAILURE;
  }

  LOG_INFO << "Starting aklite client with " << interval << " second interval";

  auto current = client->GetCurrent();
  while (true) {
    LOG_INFO << "Active Target: " << current.Name() << ", sha256: " << current.Sha256Hash();
    LOG_INFO << "Checking for a new Target...";

    try {
      CheckInResult res = !is_local_update?
                           client->CheckIn():
                           client->CheckInLocal(&local_update_source);
      if (res.status != CheckInResult::Status::Ok && res.status != CheckInResult::Status::OkCached) {
        LOG_WARNING << "Unable to update latest metadata, going to sleep for " << interval
                    << " seconds before starting a new update cycle";
        std::this_thread::sleep_for(std::chrono::seconds(interval));
        continue;  // There's no point trying to look for an update
      }

      auto latest = res.GetLatest();
      if (client->IsRollback(latest)) {
        LOG_INFO << "Latest Target is marked for causing a rollback and won't be installed: " << latest.Name();
      } else {
        LOG_INFO << "Found Latest Target: " << latest.Name();
      }

      if (client->IsRollback(latest) && current.Name() == latest.Name()) {
        // Handle the case when Apps failed to start on boot just after an update.
        // This is only possible with `pacman.create_containers_before_reboot = 0`.
        LOG_INFO << "The currently booted Target is a failing Target, finding Target to rollback to...";
        const TufTarget rollback_target = client->GetRollbackTarget();
        if (rollback_target.IsUnknown()) {
          LOG_ERROR << "Failed to find Target to rollback to after failure to start Apps at boot of a new sysroot";
          std::this_thread::sleep_for(std::chrono::seconds(interval));
          continue;
        }
        latest = rollback_target;
        LOG_INFO << "Rollback Target is " << latest.Name();
      }

      if (latest.Name() != current.Name() && !client->IsRollback(latest)) {
        std::string reason = "Updating from " + current.Name() + " to " + latest.Name();
        auto installer = client->Installer(latest, reason, "", InstallMode::All,
                                      is_local_update ? &local_update_source : nullptr);
        if (!installer) {
          LOG_ERROR << "Found latest Target but failed to retrieve its metadata from DB, skipping update";
          std::this_thread::sleep_for(std::chrono::seconds(interval));
          continue;
        }
        auto dres = installer->Download();
        if (dres.status != DownloadResult::Status::Ok) {
          LOG_ERROR << "Unable to download target: " << dres;
          continue;
        }
        auto ires = installer->Install();
        if (ires.status == InstallResult::Status::Ok) {
          current = latest;
          continue;
        } else if (ires.status == InstallResult::Status::BootFwNeedsCompletion) {
          LOG_ERROR << "Cannot start installation since the previous boot fw update requires device rebooting; "
                    << "the client will start the target installation just after reboot.";
          reboot(reboot_cmd);
        } else if (ires.status == InstallResult::Status::NeedsCompletion) {
          reboot(reboot_cmd);
          break;
        } else {
          LOG_ERROR << "Unable to install target: " << ires;
        }
      } else if (!is_local_update || client->IsRollback(latest)) {
        auto installer = client->CheckAppsInSync();
        if (installer != nullptr) {
          LOG_INFO << "Syncing Active Target Apps";
          auto dres = installer->Download();
          if (dres.status != DownloadResult::Status::Ok) {
            LOG_ERROR << "Unable to download target: " << dres;
          } else {
            auto ires = installer->Install();
            if (ires.status != InstallResult::Status::Ok) {
              LOG_ERROR << "Unable to install target: " << ires;
            }
          }
        }
      } else {
        LOG_INFO << "Device is up-to-date";
      }
    } catch (const std::exception &exc) {
      LOG_ERROR << "Failed to find or update Target: " << exc.what();
      continue;
    }

    std::this_thread::sleep_for(std::chrono::seconds(interval));
  }
  return EXIT_FAILURE;
}
