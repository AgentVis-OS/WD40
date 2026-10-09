#!/bin/bash
# lmi (POCO F2 Pro) hardcoded convenience wrapper - the device-specific
# variant of the app repo's generic build.sh for this machine's setup.
# Requires: AOSP tree owned by the invoking user (no sudo needed).
set -e
exec "$(dirname "$(readlink -f "$0")"/../../..)/../aiphone_assistant/build.sh" \
    /home/inoki/Builds/LineageOS/lineage-22_2-poco-f2 \
    lineage_lmi-ap3a-userdebug lmi
