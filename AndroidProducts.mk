# AgentVis product registration.
#
# With this repo synced to vendor/wd40 (see
# integrations/aiphoneassistant/local_manifests/), the lineage_wd40_*
# targets appear in lunch:
#   lunch lineage_wd40_lmi-ap3a-userdebug
# which builds stock lineage_lmi + the AI Phone Assistant integration.
# The "lineage_" prefix is required by vendor/lineage to derive
# LINEAGE_BUILD (version/OTA suffix); the release segment (ap3a) follows
# the host LineageOS version.

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/devices/lmi/lineage_wd40_lmi.mk

COMMON_LUNCH_CHOICES := \
    lineage_wd40_lmi-ap3a-userdebug \
    lineage_wd40_lmi-ap3a-eng
