#include <iostream>
#include <thread>

#include <boost/filesystem.hpp>
#include <boost/log/core.hpp>
#include <boost/log/expressions.hpp>
#include <boost/log/trivial.hpp>
#include <boost/process.hpp>

#include "aktualizr-lite/api.h"
#include "aktualizr-lite/aklite_client_ext.h"
#include "aktualizr-lite/cli/cli.h"
#include "cli.h"

#define LOG_INFO BOOST_LOG_TRIVIAL(info)
#define LOG_WARNING BOOST_LOG_TRIVIAL(warning)
#define LOG_ERROR BOOST_LOG_TRIVIAL(error)

static void print_status(aklite::cli::StatusCode ret) {
    auto success_string = aklite::cli::IsSuccessCode(ret)? "SUCCESS" : "FAILURE";
    std::cout << success_string << ": " << aklite::cli::StatusCodeDescription(ret) << std::endl;
}

static std::unique_ptr<AkliteClientExt> init_client(bool online_mode) {
  boost::log::core::get()->set_filter(boost::log::trivial::severity >= boost::log::trivial::info);

  std::vector<boost::filesystem::path> cfg_dirs;

  auto env{boost::this_process::environment()};
  if (env.end() != env.find("AKLITE_CONFIG_DIR")) {
    cfg_dirs.emplace_back(env.get("AKLITE_CONFIG_DIR"));
  } else if (online_mode) {
    cfg_dirs = AkliteClient::CONFIG_DIRS;
  } else {
    // sota.toml is optional in offline mode
    for (const auto& cfg : AkliteClient::CONFIG_DIRS) {
      if (boost::filesystem::exists(cfg)) {
        cfg_dirs.emplace_back(cfg);
      }
    }
  }

  try {
    return std::make_unique<AkliteClientExt>(cfg_dirs, false, false);
  } catch (const std::exception& exc) {
    LOG_ERROR << "Failed to initialize the client: " << exc.what();
    return nullptr;
  }
}

int cmd_check(std::string local_repo_path) {
  auto client = init_client(local_repo_path.empty());
  if (client == nullptr) {
    return EXIT_FAILURE;
  }

  LocalUpdateSource local_update_source;
  if (local_repo_path.empty()) {
    LOG_INFO << "Online mode";
  } else {
    auto abs_repo_path = boost::filesystem::canonical(local_repo_path).string();
    LOG_INFO << "Offline mode. Updates path=" << abs_repo_path;
    local_update_source = {abs_repo_path + "/tuf", abs_repo_path + "/ostree_repo", abs_repo_path + "/apps"};
  }

  auto status = aklite::cli::CheckIn(*client, local_repo_path.empty() ? nullptr : &local_update_source);
  print_status(status);
  return aklite::cli::IsSuccessCode(status) ? EXIT_SUCCESS : EXIT_FAILURE;
}

int cmd_pull(std::string target_name, std::string local_repo_path) {
  auto client = init_client(local_repo_path.empty());
  if (client == nullptr) {
    return EXIT_FAILURE;
  }

  LocalUpdateSource local_update_source;
  if (local_repo_path.empty()) {
    LOG_INFO << "Online mode";
  } else {
    auto abs_repo_path = boost::filesystem::canonical(local_repo_path).string();
    LOG_INFO << "Offline mode. Updates path=" << abs_repo_path;
    local_update_source = {abs_repo_path + "/tuf", abs_repo_path + "/ostree_repo", abs_repo_path + "/apps"};
  }

  auto status =
      aklite::cli::Pull(*client, -1, target_name, true, local_repo_path.empty() ? nullptr : &local_update_source);
  print_status(status);
  return aklite::cli::IsSuccessCode(status) ? EXIT_SUCCESS : EXIT_FAILURE;
}

int cmd_install(std::string target_name, std::string local_repo_path) {
  auto client = init_client(local_repo_path.empty());
  if (client == nullptr) {
    return EXIT_FAILURE;
  }

  LocalUpdateSource local_update_source;
  if (local_repo_path.empty()) {
    LOG_INFO << "Online mode";
  } else {
    auto abs_repo_path = boost::filesystem::canonical(local_repo_path).string();
    LOG_INFO << "Offline mode. Updates path=" << abs_repo_path;
    local_update_source = {abs_repo_path + "/tuf", abs_repo_path + "/ostree_repo", abs_repo_path + "/apps"};
  }

  auto status =
      aklite::cli::Install(*client, -1, target_name, InstallMode::All, true,
                           local_repo_path.empty() ? nullptr : &local_update_source, aklite::cli::PullMode::None);
  print_status(status);
  return aklite::cli::IsSuccessCode(status) ? EXIT_SUCCESS : EXIT_FAILURE;
}

int cmd_run() {
  auto client = init_client(false);
  if (client == nullptr) {
    return EXIT_FAILURE;
  }

  auto status = aklite::cli::CompleteInstall(*client);
  print_status(status);
  return aklite::cli::IsSuccessCode(status) ? EXIT_SUCCESS : EXIT_FAILURE;
}
