#!/bin/bash
# lmi (POCO F2 Pro) hardcoded convenience wrapper - the device-specific
# variant of the app repo's generic build.sh for this machine's setup.
#
# Locates the app repo via (first match wins):
#   1. $AIPHONE_ASSISTANT_REPO
#   2. ~/aiphone_assistant
#   3. sibling of this WD40 checkout's root
set -e

AOSP_TREE="/home/inoki/Builds/LineageOS/lineage-22_2-poco-f2"
LUNCH="lineage_lmi-ap3a-userdebug"
PRODUCT="lmi"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$AIPHONE_ASSISTANT_REPO" ]; then
    APP_BUILD="$AIPHONE_ASSISTANT_REPO/build.sh"
elif [ -f "$HOME/aiphone_assistant/build.sh" ]; then
    APP_BUILD="$HOME/aiphone_assistant/build.sh"
elif [ -f "$SCRIPT_DIR/../../../aiphone_assistant/build.sh" ]; then
    # ../../.. from scripts/ is this WD40 checkout's root; the app repo is
    # expected next to it.
    APP_BUILD="$SCRIPT_DIR/../../../aiphone_assistant/build.sh"
else
    echo "Error: aiphone_assistant repo not found." >&2
    echo "Set AIPHONE_ASSISTANT_REPO=/path/to/aiphone_assistant or clone it" >&2
    echo "next to this WD40 checkout (~/aiphone_assistant works too)." >&2
    exit 1
fi

exec bash "$APP_BUILD" "$AOSP_TREE" "$LUNCH" "$PRODUCT"
