# AIPhoneAssistant — porting guide

How the agent app plugs into a standard AOSP/LineageOS workflow. Reference:
LineageOS 22.2 (Android 15), device `lmi` (Xiaomi POCO F2 Pro). For the
inventory of what/where/why: [`../../docs/system-integrations.md`](../../docs/system-integrations.md).

Canonical app source: <https://github.com/AgentVis-OS/aiphone_assistant>.

## Where this plugs into the standard build flow

```
1. repo init -u <lineageos-manifest>       # stock step
2. add .repo/local_manifests/wd40.xml  # <-- insertion point 1 (fetch)
3. repo sync                               # app -> packages/apps/, this repo -> vendor/wd40/
4. lunch lineage_wd40_lmi-ap3a-userdebug       # <-- insertion point 2 (product choice)
5. m bacon                                 # full image, nothing upstream modified
```

The `lineage_wd40_*` product (registered by `AndroidProducts.mk` at the root of
this repo) inherits the stock `lineage_lmi` product and appends the app,
its privapp allowlist and the SELinux rules — the same pattern used by
LineageOS for microG / /e/OS style distributions. Upstream files are never
edited, so `repo sync` stays clean.

For other devices: copy `lineage_wd40_lmi.mk` to `lineage_wd40_<target>.mk`, point
the `inherit-product` line at that device's stock makefile, and register it
in `AndroidProducts.mk`. Everything else (sepolicy private rules, app
modules) is device-agnostic.

## Hard requirements (all tiers)

- The APK must be built **from the same tree** it will run on (platform
  signature match) — signature permissions only grant on a matching
  signature.
- SELinux must allow `system_app` → SurfaceFlinger / InputManager (the
  `lineage_wd40_*` product adds these; see Tier B/C if you cannot use it).
- The app runs as `android.uid.system`, `system_ext_specific` + privileged.

## Tier A — build with the wd40 product (recommended)

The five steps above. First full build bakes sepolicy into the image; after
that, app-only iterations are:

```bash
m AIPhoneAssistant
adb install -r out/target/product/lmi/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk
```

(no root needed once the system copy exists; data preserved).

## Tier B — integrate into your own product by hand

For trees where you maintain the device config yourself:

1. App source into the tree (or `./build.sh <tree> <combo>` from the app
   repo, which does exactly this copy):
   ```bash
   APP_DEST=$AOSP_ROOT/packages/apps/AIPhoneAssistant
   cp -r src res "$APP_DEST/"
   cp Android.bp AndroidManifest.xml privapp-permissions-aiphoneassistant.xml proguard.flags "$APP_DEST/"
   ```
2. `device.mk` (snippet: `device.mk.snippet`):
   ```make
   PRODUCT_PACKAGES += AIPhoneAssistant privapp-permissions-aiphoneassistant
   ```
3. BoardConfig / sepolicy:
   ```make
   SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/wd40/integrations/aiphoneassistant/sepolicy/private
   # optional, capture fallback only, SoC-specific:
   BOARD_VENDOR_SEPOLICY_DIRS += vendor/wd40/integrations/aiphoneassistant/sepolicy/vendor
   ```
4. Full image build once (sepolicy must be baked), then `adb install -r` for
   day-2 updates.

## Tier C — rooted device, no ROM build (Magisk module)

`magisk/` is a working module skeleton:

- drop the platform-signed APK into `system/system_ext/priv-app/AIPhoneAssistant/`,
  zip the `magisk/` dir, flash in Magisk
- `post-fs-data.sh` live-patches SELinux (`magiskpolicy --live`, same allows
  as the static rules)
- limitation: still needs a platform-signed APK matching the installed ROM.

## Developer quick path (app-only iterations, any machine)

From the app repo — no device-specific values, all inputs are arguments or
env vars:

```bash
./build.sh $AOSP_ROOT lineage_lmi-ap3a-userdebug     # or AOSP_ROOT/LUNCH_COMBO env
adb install -r out/target/product/lmi/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk
```

## Known pitfalls

- `avc: denied` in `dmesg` during capture/injection → SELinux rules missing
  or not flashed.
- `INSTALL_FAILED_...` when updating a priv-app that is not yet on the
  system partition → flash once, or use root remount.
- adbd root / "Root debugging" is NOT needed for day-2 app updates.
- Reasoning LLMs may return empty `content` (chain-of-thought only): the app
  falls back to `reasoning_content` and uses a large `max_tokens`; keep the
  gateway's per-request timeout above the app's 90 s round budget.
