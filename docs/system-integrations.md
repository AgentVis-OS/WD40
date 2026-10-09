# System-side integrations — inventory and generalization notes

Every change made **outside the app source tree** to get an agent system app
(currently AIPhoneAssistant) running on an AOSP/LineageOS build. Each entry:
what / where / why, plus what is device-specific vs. general.

Reference device: Xiaomi POCO F2 Pro (`lmi`, sm8250-common), LineageOS 22.2
(Android 15), platform-signed `system_ext` priv-app, `system_ext_specific`.

The app side (sources, `Android.bp`, manifest, privapp allowlist XML,
`build_lmi.sh`/`push.sh` scripts) lives in the
[AIPhoneAssistant repo](https://github.com/inokinoki/aiphone_assistant) and is
mirrored into the AOSP tree at `packages/apps/AIPhoneAssistant/` by the build
script — it is **not** re-listed here.

---

## 1. SELinux — private (system_ext) policy  ← REQUIRED

- **File**: `device/<vendor>/<common>/sepolicy/private/aiphoneassistant.te`
  (concrete copy: [`integrations/aiphoneassistant/sepolicy/private/`](../integrations/aiphoneassistant/sepolicy/private/))
- **Why**: the app runs as `android.uid.system` (sharedUserId) + platform
  signature, so it lands in the `system_app` SELinux domain. Core policy does
  **not** grant `system_app` access to:
  - `surfaceflinger_service:service_manager find` + `binder_call` +
    `fd use` — needed for `WindowManager.captureDisplay()` screen capture
  - `input_service:service_manager find` — needed for
    `InputManager.injectInputEvent()`
  Without these the operations fail with silent `avc: denied` (app runs,
  capture/injection just doesn't work — check `dmesg | grep avc`).
- **Picked up via**: `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/private`
  (already set in LineageOS `BoardConfigCommon.mk` for sm8250-common; verify
  on other targets).
- **Generalizes**: 100% device-agnostic — these are binder/service allows for
  `system_app`, no device nodes involved. Copy as-is for any target.
- **Takes effect only after a full image build + flash** — sepolicy cannot be
  pushed at runtime.

## 2. SELinux — vendor policy  ← OPTIONAL (capture fallback only)

- **File**: `device/<vendor>/<common>/sepolicy/vendor/aiphoneassistant.te`
  (copy: [`integrations/aiphoneassistant/sepolicy/vendor/`](../integrations/aiphoneassistant/sepolicy/vendor/))
- **Why**: device-node allows (`gpu_device`, `ion_device`, `graphics_device`,
  `ashmem_device`) for the VirtualDisplay + ImageReader **capture fallback**
  path. The primary `captureDisplay()` path needs none of these.
- **Generalizes**: device-specific by nature (Qualcomm Adreno `/dev/kgsl-3d0`
  on sm8250; other SoCs have their own types). Start without this file; add
  rules only from `audit2allow` output if the fallback path hits denials.
  Beware `neverallow` failures on strict builds (see the caution header in
  the .te file).

## 3. Product makefile  ← REQUIRED

- **File**: `device/<oem>/<target>/device.mk` (snippet:
  [`integrations/aiphoneassistant/device.mk.snippet`](../integrations/aiphoneassistant/device.mk.snippet))
- **Content**:
  ```make
  PRODUCT_PACKAGES += AIPhoneAssistant privapp-permissions-aiphoneassistant
  ```
- **Why**: adds the app APK and the privapp allowlist to the system image
  (`/system/system_ext/priv-app/AIPhoneAssistant/` + `/system/system_ext/etc/permissions/`).
- **Generalizes**: target-agnostic; module names come from the app's
  `Android.bp` (`android_app` name + the `prebuilt_etc` for the allowlist).

## 4. Runtime install / update path  ← no build-tree change

Privileged system apps can be **updated without root or reflash** as long as
the package already exists on the system partition:

```bash
adb install -r out/target/product/<target>/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk
```

- Works because the update is platform-signed and inherits the privileged
  flags of the system copy (verified: `PRIVATE_FLAG_PRIVILEGED` retained).
- Data (SQLite chat store, prefs/API config) survives updates.
- First-time install onto a device *without* the system copy, or changes to
  the privapp allowlist / SELinux / manifest `sharedUserId`, DO require root
  remount or a flashed image.

## 5. Requirements the app itself imposes on the system  ← FYI

- Platform signature (`certificate: "platform"`) — signature permissions
  (`READ_FRAME_BUFFER`, `INJECT_EVENTS`, `INTERNAL_SYSTEM_WINDOW`,
  `CAPTURE_*`) auto-grant; privileged allowlist XML covers the
  `signature|privileged` ones.
- `sharedUserId="android.uid.system"` — maps the app into the `system_app`
  SELinux domain (this is why §1 exists).
- `system_ext_specific: true` + `privileged: true` in `Android.bp`.
- `POST_NOTIFICATIONS` runtime permission is requested by the app UI on
  first launch (Android 13+).

---

## Generalization checklist for a new device

1. Copy `integrations/aiphoneassistant/sepolicy/private/*.te` into the
   target's system_ext private sepolicy dir; confirm
   `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS` includes it.
2. Either lunch `lineage_ed40_<target>` (see the runbook) or add the `PRODUCT_PACKAGES` line to the target's product makefile.
3. Build the full image once (`m AIPhoneAssistant` alone is not enough for
   sepolicy), flash, then iterate with `adb install -r` for app updates.
4. Only if the capture fallback is exercised: add vendor sepolicy rules from
   `audit2allow` on that device.
5. Sanity check: `dmesg | grep avc | grep aiphone` (or the new package name)
   should stay quiet during a task run.
