# WD40

Integration glue and system-side change log for the **AgentVis OS** device
projects. WD40 records everything an agent app needs *outside of its own
source tree* — SELinux policy, product makefile entries, privileged
permission allowlists, image-build and deployment runbooks — so these changes
are versioned, reviewable, and reusable across devices instead of living as
uncommitted local edits inside someone's LineageOS/AOSP tree.

## Why "WD40"

Where LineageOS takes its name from *lineage* — a bloodline carried on
after CyanogenMod ended — WD40 is the bloodline's counterpart for machines:
what gets passed down the generations of an AgentVis OS device is not blood
but the lubricant. The SELinux rules, product configs and runbooks kept
here are what each new device generation inherits, so the lineage keeps
moving. Hence the lunch products read `lineage_wd40_<target>`: lineage
above, WD-40 within.

## Relationship to other projects

| Project | Contains | Hosted |
|---|---|---|
| [AIPhoneAssistant](https://github.com/AgentVis-OS/aiphone_assistant) | The agent app itself (Java sources, res, manifest, Android.bp, privapp allowlist, `build.sh`) | GitHub (**AgentVis-OS** org) |
| **WD40** (this repo) | Everything the app needs *in the system/build tree*: sepolicy rules, `lineage_wd40_*` lunch products, integration runbooks, generalized how-tos | GitHub (**AgentVis-OS** org) |

Rule of thumb: if deleting it would break the *app build*, it belongs to the
app repo; if deleting it would break the *system integration* (install,
permissions, SELinux, flashing), it belongs here.

## Contents

- [`docs/system-integrations.md`](docs/system-integrations.md) — the full
  inventory of system-side changes made so far, each with what / where / why
  and notes on generalizing to other devices and packages.
- `devices/<target>/lineage_wd40_<target>.mk` + the root `AndroidProducts.mk`
  registration: the stock device product plus this integration, with zero
  upstream edits.
- [`integrations/aiphoneassistant/`](integrations/aiphoneassistant/) — the
  concrete artifacts for the AIPhoneAssistant integration (sepolicy rules,
  device.mk snippet, privapp allowlist, Magisk module skeleton) plus a
  step-by-step porting guide.
