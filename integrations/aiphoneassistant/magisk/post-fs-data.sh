#!/system/bin/sh
# Live SELinux patch for AIPhoneAssistant (runs as Magisk context).
# Equivalent to the static rules in sepolicy/private/aiphoneassistant.te.
magiskpolicy --live \
  "allow system_app surfaceflinger_service service_manager find" \
  "allow system_app surfaceflinger fd use" \
  "binder_call system_app surfaceflinger" \
  "allow system_app input_service service_manager find" \
  "binder_call system_app system_server"
