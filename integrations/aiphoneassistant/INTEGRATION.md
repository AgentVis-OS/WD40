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

For other devices: create `devices/<target>/lineage_wd40_<target>.mk`
(inherit that device's stock product makefile, then add the same
PRODUCT_PACKAGES / sepolicy lines) and register it in the root
`AndroidProducts.mk`. Everything else (sepolicy private rules, app
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

(no root needed once the system copy exists; data preserved). For faster
app-only iteration see ["Faster app-only iteration"](#faster-app-only-iteration-skips-soong)
below.

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

## Faster app-only iteration (skips Soong)

`m AIPhoneAssistant` re-runs Soong analysis on every invocation, which costs
minutes on large trees even for a one-file change. For **Java-only** changes,
once the tree has any successful full build, rebuild in ~2 minutes directly
from the app repo. All inputs come from the previous build; `$TREE` is the
AOSP/LineageOS tree root:

```bash
FRAMEWORK=$TREE/out/target/common/obj/JAVA_LIBRARIES/framework-minus-apex_intermediates/classes.jar
CORE_LIBART=$TREE/out/target/common/obj/JAVA_LIBRARIES/core-libart.com.android.art_intermediates/classes.jar
CORE_OJ=$TREE/out/target/common/obj/JAVA_LIBRARIES/core-oj.com.android.art_intermediates/classes.jar
APP_JAR=$TREE/out/soong/.intermediates/packages/apps/AIPhoneAssistant/AIPhoneAssistant/android_common/javac/AIPhoneAssistant.jar
OLD_APK=$TREE/out/target/product/<target>/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk
```

1. Compile the app sources against the previous build's jars:

   ```bash
   find <app-repo>/src -name '*.java' > sources.txt
   $TREE/prebuilts/jdk/jdk21/linux-x86/bin/javac -source 17 -target 17 \
     -nowarn -encoding UTF-8 -d classes @sources.txt \
     -classpath "$FRAMEWORK:$CORE_LIBART:$CORE_OJ:$APP_JAR"
   ```

   Gotchas: `org.json` lives in **core-libart** (not framework-minus-apex);
   the generated `R` classes come from the previous javac jar (`APP_JAR` —
   the `busybox/R.jar` next to it is incomplete).

2. Dex:

   ```bash
   find classes -name '*.class' > classlist.txt
   $TREE/out/host/linux-x86/bin/d8 --release --min-api 34 \
     --lib "$FRAMEWORK" --output dex @classlist.txt
   ```

3. Swap the dex into the previous APK and re-sign with the tree's platform
   key (must match what signed the image — for `-userdebug` builds that is
   the AOSP test platform key):

   ```bash
   cp "$OLD_APK" new.apk && zip -q new.apk dex/classes.dex
   $TREE/out/host/linux-x86/bin/zipalign -f 4 new.apk aligned.apk
   $TREE/out/host/linux-x86/bin/apksigner sign \
     --key $TREE/build/target/product/security/platform.pk8 \
     --cert $TREE/build/target/product/security/platform.x509.pem \
     --out AIPhoneAssistant.apk aligned.apk
   adb install -r AIPhoneAssistant.apk
   ```

Resource or manifest changes additionally need `aapt2 compile`/`link` to
regenerate the resource base (framework-res for `-I` lives at
`$TREE/out/target/product/<target>/obj/APPS/framework-res_intermediates/package.apk`);
Java-only edits can skip it. The app repo's `AGENTS.md` tracks the same
pipeline with exact verified commands.

## Known pitfalls

- `avc: denied` in `dmesg` during capture/injection → SELinux rules missing
  or not flashed.
- `INSTALL_FAILED_...` when updating a priv-app that is not yet on the
  system partition → flash once, or use root remount.
- adbd root / "Root debugging" is NOT needed for day-2 app updates.
- Reasoning LLMs may return empty `content` (chain-of-thought only): the app
  falls back to `reasoning_content` and uses a large `max_tokens`; keep the
  gateway's per-request timeout above the app's round budget (300 s with a
  two-stage abort: cancel, then force-recover 15 s later).
