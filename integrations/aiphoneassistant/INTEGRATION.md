# AIPhoneAssistant — system integration runbook

Concrete steps to embed the AIPhoneAssistant agent app into an AOSP/LineageOS
build. Reference integration: LineageOS 22.2 (Android 15), target `lmi`
(Xiaomi POCO F2 Pro). Generalization notes: see
[`../../docs/system-integrations.md`](../../docs/system-integrations.md).

Canonical app source: <https://github.com/inokinoki/aiphone_assistant>
(all build/deploy scripts referenced below live there).

## 0. Prerequisites

- A platform-signed build you control (`userdebug` is fine) with the app's
  key in the build's signing config — otherwise signature permissions will
  not grant.
- `adb` working; for first-time install onto a device without the system
  copy you need either a flashed image or root remount (see §4).

## 1. Put the app source into the build tree

```bash
AOSP_ROOT=/path/to/lineage
APP_SOURCE=/path/to/aiphone_assistant
APP_DEST=$AOSP_ROOT/packages/apps/AIPhoneAssistant

cp -r "$APP_SOURCE/src" "$APP_SOURCE/res" "$APP_DEST/"
cp "$APP_SOURCE"/{Android.bp,AndroidManifest.xml,privapp-permissions-aiphoneassistant.xml,proguard.flags} "$APP_DEST/"
```

(`build_lmi.sh` in the app repo automates this for lmi.)

## 2. Register the modules in the target

Add to the target's product makefile (see `device.mk.snippet`):

```make
PRODUCT_PACKAGES += AIPhoneAssistant privapp-permissions-aiphoneassistant
```

## 3. Install the SELinux rules

```bash
COMMON=$AOSP_ROOT/device/<vendor>/<common>
cp sepolicy/private/aiphoneassistant.te "$COMMON/sepolicy/private/"
cp sepolicy/vendor/aiphoneassistant.te   "$COMMON/sepolicy/vendor/"   # optional, see docs
```

The private rules are **required** (screen capture + input injection).
Rules only take effect after a full image build + flash.

## 4. Build, flash, first boot

```bash
source build/envsetup.sh && lunch <product>-<release>-<variant>
m AIPhoneAssistant -j"$(nproc)"      # app-only build (no sepolicy change)
# sepolicy changed? build/flash the full image instead.
```

Output APK:
`out/target/product/<target>/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk`

## 5. Day-2 app updates (no root)

```bash
adb install -r out/target/product/<target>/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk
```

Privileged flags and permissions survive the update (platform-signed update
of a system app). Data directory (`/data/data/<package>/`, holds the SQLite
chat store + API config) survives too.

## 6. Known pitfalls

- `avc: denied` in `dmesg` during capture/injection → sepolicy §3 missing or
  not flashed.
- `INSTALL_FAILED_...` on `adb install` of the priv-app → the device copy
  was never on the system partition; flash once or use root remount.
- Enabling "Root debugging" / adbd root is NOT needed for app updates, only
  for pushing into `/system` directly.
- Reasoning LLMs may return empty `content` (chain-of-thought only): the app
  falls back to `reasoning_content` and uses a large `max_tokens`; keep the
  gateway's per-request timeout above the app's 90 s round budget.
