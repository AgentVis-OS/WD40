ui_print "- AgentVis AI Phone Assistant"
# The APK must be signed with this ROM's platform key; verify before install.
if ! grep -q "ro.build.tags=release-keys\|test-keys" /system/build.prop; then
  ui_print "! Could not read build tags — verify signing manually"
fi
ui_print "- SELinux rules are patched in post-fs-data.sh (magiskpolicy --live)"
ui_print "- If capture/injection fails, run: dmesg | grep avc"
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
