# Architecture & flow diagrams

Mermaid sources (rendered by GitHub); rendered PNGs live in `img/`.

## 1. Porting / build flow — where the integration plugs in

Two insertion points (marked ★) into the standard LineageOS workflow; the
three tiers below cover different audiences.

```mermaid
flowchart TD
    start(["Porter with a device"]) --> q{"How do you build?"}

    q -->|"I build my ROM<br/>(Tier A, recommended)"| a1["repo init -u lineage manifest<br/>(stock step)"]
    a1 --> a2["★1 copy wd40.xml into<br/>.repo/local_manifests/"]
    a2 --> a3["repo sync"]
    a3 --> a4["app → packages/apps/AIPhoneAssistant<br/>WD40 → vendor/wd40"]
    a4 --> a5["★2 lunch lineage_wd40_&lt;target&gt;-ap3a-userdebug<br/>(product inherits stock lineage_&lt;target&gt;)"]
    a5 --> a6["m bacon — full image"]
    a6 --> a7["flash once (bakes SELinux)"]
    a7 --> day2["day-2 app updates:<br/>m AIPhoneAssistant && adb install -r<br/>(no root, data kept)"]

    q -->|"I maintain the device config<br/>(Tier B)"| b1["copy app sources into tree<br/>(or app-repo build.sh)"]
    b1 --> b2["device.mk: PRODUCT_PACKAGES += …"]
    b2 --> b3["BoardConfig: SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += …"]
    b3 --> a6

    q -->|"rooted stock ROM,<br/>no build (Tier C)"| c1["Magisk module:<br/>systemless priv-app + allowlist"]
    c1 --> c2["post-fs-data.sh:<br/>magiskpolicy --live (same allows)"]
    c2 --> c3["flash module in Magisk"]

    day2 --> run(["Task executes"])
    c3 --> run
```

## 2. System architecture — repos, build tree, device runtime

```mermaid
flowchart LR
    subgraph repos["GitHub (→ AgentVis OS org)"]
        APP["aiphone_assistant<br/>(app sources, Android.bp,<br/>privapp allowlist, build.sh)"]
        WD["WD40 (= vendor/wd40)<br/>lunch products · sepolicy ·<br/>local_manifests · magisk · docs"]
    end

    subgraph tree["AOSP / LineageOS build tree"]
        P["packages/apps/AIPhoneAssistant"]
        V["vendor/wd40"]
        D["device/&lt;vendor&gt;/&lt;target&gt;<br/>(upstream — never edited)"]
        IMG["image: system_ext/priv-app/…apk<br/>+ permissions XML + SELinux policy"]
    end

    APP -->|local_manifests sync| P
    WD -->|local_manifests sync| V
    V -->|"lineage_wd40_&lt;target&gt;<br/>inherit-product + += "| IMG
    P --> IMG
    D -->|stock product inherits| IMG

    subgraph device["Device runtime"]
        SVC["AIPhoneAssistantService<br/>(FG service, system_app domain)"]
        CAP["ScreenCaptureService<br/>captureDisplay"]
        INJ["InputInjectionService<br/>injectInputEvent"]
        LLM["LLMClientService<br/>OpenAI-compatible HTTP"]
        UI["ConversationListActivity<br/>ChatActivity · SettingsActivity"]
        OV["OverlayController<br/>interrupt bar + confirm dialog<br/>(TYPE_STATUS_BAR_ADDITIONAL)"]
        DB[("SQLite chat.db<br/>conversations / messages /<br/>images (BLOB)")]
        NTF["notifications:<br/>live task + result"]
        SF["SurfaceFlinger"]
        IM["InputManager"]
        CLOUD["LLM endpoint<br/>(GLM / OpenAI / …)"]
    end

    IMG -->|flash / adb install -r| SVC
    SVC --> CAP -->|"sepolicy allow"| SF
    SVC --> INJ -->|"sepolicy allow"| IM
    SVC <--> LLM --> CLOUD
    SVC --> OV
    SVC --> DB
    SVC --> NTF
    UI <-->|state broadcast| SVC
    UI --> DB
```

## 3. Task lifecycle (one conversation per task)

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> pending: send task (new conversation)
    pending --> executing: service ACTIVATE
    executing --> paused: triple-tap interrupt bar
    paused --> executing: dialog "continue" (re-baseline)
    paused --> interrupted: dialog "stop task"
    executing --> done: model replies done(summary)
    executing --> stalled: watchdog exhausted / LLM errors
    executing --> stopped: assistant disabled / service killed
    done --> idle: deactivated, notification sent
    interrupted --> idle
    stalled --> idle
    stopped --> idle
```
