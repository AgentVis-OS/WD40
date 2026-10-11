# AgentVis build of LineageOS for lmi (POCO F2 Pro):
# everything from the stock lineage_lmi target plus the AI Phone Assistant
# system integration (app + privapp allowlist + SELinux allows).
#
# No upstream file is modified: this product inherits the device's stock
# makefile and appends on top.

$(call inherit-product, device/xiaomi/lmi/lineage_lmi.mk)

# Keep the product name consistent with the lunch target (the stock
# makefile sets PRODUCT_NAME := lineage_lmi).
PRODUCT_NAME := lineage_wd40_lmi

# App APK + privileged-permission allowlist (module names from the app's Android.bp).
PRODUCT_PACKAGES += AIPhoneAssistant privapp-permissions-aiphoneassistant

# Required SELinux allows (system_app -> SurfaceFlinger capture, InputManager
# injection). Path is relative to the tree root; this repo is synced to
# vendor/wd40 by local_manifests.
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/wd40/integrations/aiphoneassistant/sepolicy/private

# Optional: capture-fallback device nodes (Qualcomm sm8250; see
# integrations/aiphoneassistant/sepolicy/vendor/ for the caveats).
BOARD_VENDOR_SEPOLICY_DIRS += vendor/wd40/integrations/aiphoneassistant/sepolicy/vendor
