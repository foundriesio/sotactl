# Prerequisites
1. Linux host/VM (tested on Ubuntu and Arch Linux)
2. Docker engine and client, version >= 20.10.xx
3. Docker compose, version >= 2.22.0

# Set required environment variables
1. `FACTORY` - Name of your FoundriesFactory.
2. `USER_TOKEN` - Token to access your FoundriesFactory obtained from [Foundries.io settings page](https://app.foundries.io/settings/tokens/).

# Development in the development container
Run `./dev-shell.sh`. The initial/first run may take some time as necessary container images are downloaded and built. Subsequent runs will be faster.

## Register/Unregister device
Inside the development container, run `make register` or `make unregister` to register or unregister a device, respectively.
Override the `DEVICE_TAG` environment variable if you need to register a device and set its tag to a non-default value (`main`).
For example, `DEVICE_TAG=devel make register`.

## Build your SOTA client
Run `make` to build your SOTA (Software Over-The-Air) client.

## Configure your development device
You can add additional configuration `*.toml` snippets to the default device configuration by placing them in `<sota-project-home-dir>/.device/etc.sota`.

## Check/Update local TUF metadata
Run `make check` to update the local TUF (The Update Framework) repository and get a list of available targets. Alternatively, run `./build/sotactl check`.

## Update your development device
1. Run `make update` to update your development device to the latest available target. The initial update may take some time since it pulls the target's ostree repository from scratch. Subsequent updates are faster as they pull only the differences between two commits.
2. If a device reboot is required, run `make reboot`.
3. Finalize the update and run updated apps, if any, by running `make run`.

## Develop and debug your SOTA client
After the initial update, you can continue developing and debugging your custom SOTA client:
1. Make code changes.
2. Build the code with `make`.
3. Run or debug one of the SOTA client commands, for example:
   ```bash
   ./build/sotactl check     # Check for TUF metadata changes and update local TUF repository if any changes are found
   ./build/sotactl pull [<target>]     # Pull the specified target content (ostree and/or apps)
   ./build/sotactl install [<target>]  # Install the pulled target
   ./build/sotactl run       # Finalize target installation if required after a device reboot

   gdb --args ./build/sotactl [<command&params>]   # Debug


### Emulating device reboot
To emulate a device reboot in the development container, remove the `/var/run/aktualizr-session/need_reboot` file if it exists.
