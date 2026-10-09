# AgentVis / AIPhoneAssistant — product wiring.
#
# Usage (after `repo sync`, with this repo at vendor/agentvis):
#   1. device.mk:      include vendor/agentvis/agentvis.mk
#   2. BoardConfig.mk: SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/agentvis/sepolicy/private
#      (optional capture-fallback device rules:)
#      BOARD_VENDOR_SEPOLICY_DIRS   += vendor/agentvis/sepolicy/vendor
#
# Paths in sepolicy dir variables are relative to the tree root, so keep the
# checkout path or adjust the two lines above.

PRODUCT_PACKAGES += AIPhoneAssistant privapp-permissions-aiphoneassistant
