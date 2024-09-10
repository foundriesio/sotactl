#!/bin/env bash

#
# Aktualizr-lite command line interface usage example script
#
# Copyright (C) 2024 Foundries.io
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Relevant aktualizr-lite CLI return codes for controlling execution flow
OK=0
CHECKIN_OK_CACHED=3

UPDATE_NEW_VERSION=16
UPDATE_SYNC_APPS=17
UPDATE_ROLLBACK=18

REBOOT_REQUIRED_BOOT_FW=90
REBOOT_REQUIRED_ROOT=100

# Commands
reboot_cmd="/sbin/reboot"
aklite_cmd="/bin/aktualizr-lite"

# Interval between each update server polling (seconds)
interval=60

# Complete previous installation, if pending
$aklite_cmd run; ret=$?
if [ $ret -eq $REBOOT_REQUIRED_ROOT ]; then
    echo "A system reboot is required to finalize the pending installation."
    exit 1
fi

while true; do
    echo "Checking for updates..."
    $aklite_cmd check; ret=$?
    if [ $ret -eq $UPDATE_NEW_VERSION -o $ret -eq $UPDATE_SYNC_APPS -o $ret -eq $UPDATE_ROLLBACK ]; then
        echo "There is a target that is meant to be installed (check returned $ret). Pulling..."
        $aklite_cmd pull; ret=$?
        if [ $ret -eq $OK ]; then
            echo "Pull operation successful. Installing..."
            $aklite_cmd install; ret=$?
            if [ $ret -eq $REBOOT_REQUIRED_ROOT -o $ret -eq $REBOOT_REQUIRED_BOOT_FW ]; then
                echo "Installation completed, reboot required ($ret)"
                break
            elif [ $ret -eq $OK ]; then
                echo "Installation completed, no reboot needed"
                continue
            else
                echo "Installation failed with error $ret"
            fi
        else
            echo "Pull operation failed with error $ret"
        fi
    elif [ $ret -eq $OK -o $ret -eq $CHECKIN_OK_CACHED ]; then
        echo "No update is needed"
    else
        echo "Check operation failed with error $ret"
    fi
    echo "Sleeping $interval seconds..."
    sleep $interval
done

echo "Rebooting ($reboot_cmd)..."
$reboot_cmd
