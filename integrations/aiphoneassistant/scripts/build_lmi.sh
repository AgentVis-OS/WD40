#!/bin/bash
# lmi (POCO F2 Pro) convenience wrapper around the app repo's generic
# build.sh, pre-filling this machine's values. Both are overridable:
#
#   scripts/build_lmi.sh                      # defaults below
#   scripts/build_lmi.sh /other/tree lineage_lmi-ap3a-eng
#
# Locates the app repo via (first match wins):
#   1. $AIPHONE_ASSISTANT_REPO
#   2. ~/aiphone_assistant
#   3. sibling of this WD40 checkout's root
set -e

AOSP_TREE="${1:-/home/inoki/Builds/LineageOS/lineage-22_2-poco-f2}"
LUNCH="${2:-lineage_lmi-ap3a-userdebug}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$AIPHONE_ASSISTANT_REPO" ]; then
    APP_BUILD="$AIPHONE_ASSISTANT_REPO/build.sh"
elif [ -f "$HOME/aiphone_assistant/build.sh" ]; then
    APP_BUILD="$HOME/aiphone_assistant/build.sh"
elif [ -f "$SCRIPT_DIR/../../../aiphone_assistant/build.sh" ]; then
    APP_BUILD="$SCRIPT_DIR/../../../aiphone_assistant/build.sh"
else
    echo "Error: aiphone_assistant repo not found." >&2
    echo "Set AIPHONE_ASSISTANT_REPO=/path/to/aiphone_assistant or clone it" >&2
    echo "next to this WD40 checkout (~/aiphone_assistant works too)." >&2
    exit 1
fi

exec bash "$APP_BUILD" "$AOSP_TREE" "$LUNCH"
