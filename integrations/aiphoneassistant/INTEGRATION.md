# AIPhoneAssistant — porting guide

Three tiers, pick by audience. Reference integration: LineageOS 22.2
(Android 15), target `lmi` (Xiaomi POCO F2 Pro). Generalization notes:
[`../../docs/system-integrations.md`](../../docs/system-integrations.md).

Canonical app source: <https://github.com/inokinoki/aiphone_assistant>.

## Hard requirements (all tiers)

- The APK must be signed with **the same platform key as the ROM** —
  signature permissions (`READ_FRAME_BUFFER`, `INJECT_EVENTS`,
  `INTERNAL_SYSTEM_WINDOW`, …) only grant on a matching signature. A self
  built ROM ships AOSP testkeys (or your release keys), so build the app from
  the same tree.
- SELinux must allow `system_app` → SurfaceFlinger / InputManager. Either
  baked into the image (Tier A/B) or live-patched (Tier C).
- The app runs as `android.uid.system` and is `system_ext_specific` +
  `privileged` — it is a system component, not a normal sideload.

## Tier A — ROM builders, one-time setup (recommended)

Fastest full integration, survives every future build:

1. Copy `local_manifests/agentvis.xml` into `.repo/local_manifests/`, then:
   `repo sync aiphone_assistant WD40`
   (app → `packages/apps/AIPhoneAssistant`, this repo → `vendor/agentvis`)
2. `device.mk`:      `include vendor/agentvis/agentvis.mk`
3. `BoardConfig.mk`: `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/agentvis/sepolicy/private`
   (optional fallback rules: `BOARD_VENDOR_SEPOLICY_DIRS += vendor/agentvis/sepolicy/vendor`)
4. Build + flash the image once (sepolicy needs an image), then the app can
   be updated day-2 with plain `adb install -r` — no root, data preserved.

Manual, repo-by-repo equivalent of the above: keep reading.

## Tier B — manual build-tree setup (equivalent to Tier A, step by step)

1. Put the app source into the build tree:

   ```bash
   AOSP_ROOT=/path/to/lineage
   APP_SOURCE=/path/to/aiphone_assistant
   APP_DEST=$AOSP_ROOT/packages/apps/AIPhoneAssistant
   cp -r "$APP_SOURCE/src" "$APP_SOURCE/res" "$APP_DEST/"
   cp "$APP_SOURCE"/{Android.bp,AndroidManifest.xml,privapp-permissions-aiphoneassistant.xml,proguard.flags} "$APP_DEST/"
   ```

   (`build_lmi.sh` in the app repo automates this for lmi.)

2. Register the modules in the target's product makefile (see
   `device.mk.snippet`):

   ```make
   PRODUCT_PACKAGES += AIPhoneAssistant privapp-permissions-aiphoneassistant
   ```

3. Install the SELinux rules:

   ```bash
   COMMON=$AOSP_ROOT/device/<vendor>/<common>
   cp sepolicy/private/aiphoneassistant.te "$COMMON/sepolicy/private/"
   cp sepolicy/vendor/aiphoneassistant.te   "$COMMON/sepolicy/vendor/"   # optional
   ```

   The private rules are **required** (screen capture + input injection).
   Rules only take effect after a full image build + flash.

4. Build, flash, first boot:

   ```bash
   source build/envsetup.sh && lunch <product>-<release>-<variant>
   m AIPhoneAssistant -j"$(nproc)"      # app-only build (no sepolicy change)
   ```

   Output APK:
   `out/target/product/<target>/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk`

## Tier C — rooted device, no ROM build (Magisk module)

`magisk/` is a working module skeleton:

- `system/system_ext/priv-app/AIPhoneAssistant/` — drop the platform-signed
  APK here, then `zip -r agentvis_aiphone.zip .` from the `magisk/` dir.
- `system/system_ext/etc/permissions/` — privapp allowlist (shipped).
- `post-fs-data.sh` — live-patches SELinux with `magiskpolicy --live`
  (same allows as the static rules).

Caveats:

- Still requires the platform-signed APK (Tier C without ROM keys cannot get
  signature permissions — no workaround short of a build).
- SELinux patch is runtime-only; re-applied by Magisk on every boot.
- Privapp allowlist via systemless overlay works on current Magisk; if
  permissions do not grant, check `dumpsys package <pkg>` for
  `PRIVATE_FLAG_PRIVILEGED` and the allowlist scan log.

## Known pitfalls

- `avc: denied` in `dmesg` during capture/injection → SELinux rules missing
  or not flashed.
- `INSTALL_FAILED_...` when updating a priv-app that is not yet on the
  system partition → flash once, or use root remount.
- adbd root / "Root debugging" is NOT needed for day-2 app updates.
- Reasoning LLMs may return empty `content` (chain-of-thought only): the app
  falls back to `reasoning_content` and uses a large `max_tokens`; keep the
  gateway's per-request timeout above the app's 90 s round budget.
