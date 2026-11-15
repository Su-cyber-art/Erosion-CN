<div align="center">
  <img src="./PreviewIcon.png" alt="Erosion Plus" width="150">
  <h1>Erosion Plus</h1>
  <p>An independent bilingual fork that can be installed alongside Erosion-CN.</p>
  <p><a href="https://github.com/Su-cyber-art/Erosion-CN">Su-cyber-art/Erosion-CN</a> · <a href="./GESTALTX_PORT.md">移植与构建说明</a></p>
</div>

---

This branch also includes GestaltX ports for **app launch images, notification sounds with on-device pairing and capture, and nine additional MG presets/restoration controls**. See [port notes and build requirements](./GESTALTX_PORT.md) and [source attribution](./THIRD_PARTY_NOTICES.md).

The 0.11.0 branch adds an Apple Watch companion and redesigns Home, Tools, Files and Settings. Keep the embedded Watch app when signing. See [Watch and port notes](./GESTALTX_PORT.md).

## Overview

**Erosion-CN** started as a Simplified Chinese fork of **[jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion)** and evolved into a heavily hardened, feature-packed toolkit. Starting with **v0.9.0**, a single IPA includes **full English + Simplified Chinese bilingual support**:
- Automatically matches your device's system language out of the box (English for all non-Chinese system locales, Simplified Chinese for `zh*`).
- Includes an instant **Language Switcher** in **Settings → App Language** (`Follow System` / `简体中文` / `English`).

> 📜 Full version history: [CHANGELOG.md](./CHANGELOG.md) · [Releases](https://github.com/Kianuni/Erosion-CN/releases)  
> 📖 Independent Architecture Deep-Dive (zh-Hans, with SVG diagrams): [*From `worse_query` Escape to `MobileGestalt` Runtime Reconstruction: Inside Erosion-CN's Bootloop-Safe In-Place Write & Dual-Vault Architecture*](https://lijianfei.com/post/erosion-cn-ios-system-configuration-mobilegestalt-architecture/)

---

## Key Improvements Over Upstream

1. **Persistent In-Place MobileGestalt Writes & Bootloop Hardening**
   - Replaces temp-file swaps (`replaceItemAt`) with a zero-byte-window in-place write protocol (`pwrite` at offset `0` + tail `ftruncate` + `fcntl(fd, F_FULLFSYNC)`), preserving original inode and `_mobilegestalt` ownership so tweaks survive reboots without reverting.
   - Avoids injecting non-cached keys (such as `RegionInfo` on iOS 27) that trigger boot-time cache invalidation, and strips brick-prone toggles (regex-sliced iPadOS mode on iPhone, fake retail supervision).
   - **Pre-Apply Diff Preview + Post-Write Readback Verification**: Previews every key/hex change before writing, saves a `PreApplyGestalt.plist` snapshot, and automatically rolls back on any readback mismatch.

2. **Lossless CoreFoundation Plist Serialization (No Camera Black Screen)**
   - Preserves exact `CFBoolean` (`<true/>` / `<false/>`) and floating-point `CFNumber` (`1.0`, `2.0`, `5.0` camera zoom factors) types via `CFBooleanGetTypeID()` and `CFNumberIsFloatType()`, passing unmodified entries through losslessly.

3. **Zero-Hardcoded Runtime `libMobileGestalt.dylib` Binary `CacheData` Engine**
   - Dynamically scans loaded `libMobileGestalt.dylib` query descriptors in memory to resolve exact `CacheUUID`, slot count, and boolean `CacheData` slot offsets for your exact device and iOS build.
   - Promotes Dynamic Island, Always-On Display, Liquid Glass Low-Power Rendering, 80% Charge Limit, Boot Chime, Crash Detection, PWM Dimming, Camera Control, Action Button, Tap to Wake, Stage Manager, Audio Mix, Spatial Audio, Responsive Shutter, Hypertension Notifications, and 14 experimental hardware capability slots to dual `CacheData + CacheExtra` writes with native hardware anti-downgrade locks.
   - **Live `MGCopyAnswer` Inspector (`MGInspectorView`)**: Compares factory backup values, staged `CacheData / CacheExtra` values, and live `MGCopyAnswer` answers side by side across all `720+` dynamic slots.

4. **Dual-Vault Factory Backup & One-Tap Factory Restore**
   - Mirrors your clean `OriginalGestalt.plist` + `SHA-256` digest into both app storage and a persistent shared system vault so your clean factory backup survives app uninstalls/reinstalls.
   - **One-Tap Factory Restore** verifies `SHA-256`, `CacheVersion`, `CacheUUID`, `CacheData` byte length, and kernel `ProductType`, restoring factory state and cleaning up Lock Screen footnote, asset tag, fake supervision leftovers, and keypad caches in one step.

5. **`CSStore2` Millisecond Container Mapper & Cross-Container Modules (`v0.8.x – v0.9.0`)**
   - **`CSStore2` (`bdsl`) Fast Container Engine**: Parses LaunchServices `.csstore` databases (with iOS 26.3.x bookmark TLV fallback and bounded `pathleak` fallback for high-inode devices) to map all app, plugin, and App Group containers in milliseconds.
   - **App & Game Save Manager (`AppDataBackupView`)**: Back up, export, and restore `Documents` + `Library/Preferences` `.zip` archives across app reinstalls (auto-resolving new container UUIDs), or jump straight into the lossless Plist/Text editor.
   - **Container Cache Cleaner (`CacheCleanerView`)**: Rank and clean `Library/Caches` and `tmp` across app containers while protecting user documents and databases.
   - **Battery Health & Thermal Telemetry (`PowerTelemetryView`)**: Zero-lock APFS `clonefile()` snapshot reader for `CurrentPowerlog.PLSQL` (`RawMaxCapacity`, cycle count, real-time wattage, cell temperature, thermal throttling history).
   - **Crash & Jetsam Analyzer (`CrashDiagnosticsView`)**: Inspect and clean `osanalytics` `.ips` crash, Jetsam (`298`), and watchdog (`210`) reports.
   - **App Group Hub & Safari Bookmarks Exporter (`AppGroupHubView`)**: Export Safari bookmarks (HTML / JSON) and generate Surge `.sgmodule` / Stash `.stoverride` routing rules.
   - **Voice Memos & Call Recording Extractor (`VoiceMemosAIView`)**: Batch-export lossless `.m4a` recordings titled via `CloudRecordings.db` and inspect on-device AI/speech model caches.

---

## Compatibility

> [!IMPORTANT]
> Always create a full computer backup before modifying system files. Use at your own risk on devices you own.

- **iOS / iPadOS 27.0 – 27.2.1 & 27.3 beta 1**: Full support (including `MobileGestalt` read/write and `CacheData` slot unlocks).
  - ⚠️ **iOS 27.3 beta 1 limitation on China (`CH/A`) hardware**: writes and most features work, but **generative cloud features (High-Quality Clean Up / Extend / Reframe, Camera `SIRI`) are blocked locally** (log: `Eligibility returned no CN region policy on a CH region code device`) and cannot be bypassed via MobileGestalt. Stay on / return to iOS 27.2.x if you need them. See FAQ #2.
- **iOS / iPadOS 26.0 – 26.7.2**: Partial support (PosterBoard wallpapers, Keypad themes, Lock Screen footnote, container browser, and read-only diagnostics; iOS 26 sandbox blocks writing to `com.apple.MobileGestalt.plist`).

---

## Installation & Sideloading

This fork builds **Erosion Plus** as `ErosionPlus_v<version>_Bilingual.ipa`.

- Bundle ID: `io.github.su-cyber-art.ErosionPlus`
- App Group: `group.io.github.su-cyber-art.ErosionPlus`
- GitHub Actions artifact: `Erosion-Plus-IPA`

Build this branch with the **Build IPA** workflow, or use `./ipabuild.sh` with full Xcode and the native build dependencies in [the port notes](./GESTALTX_PORT.md). Keep the distinct Bundle ID and App Group when re-signing. It installs alongside the original app and uses separate app storage and factory-vault filenames. Both apps still operate on the same system configuration.

The sideloading source starts with an empty app list until an independent release is published. Its sync workflow accepts only `ErosionPlus_*_Bilingual.ipa` assets whose embedded Bundle ID matches Erosion Plus; original Erosion packages are excluded.

---

## Troubleshooting & FAQ

### 1. Apply fails with `worse_query` error (`result: -1`)
- Your sideloading tool stripped the `App Group` entitlement (`(wq) Active App Group:` on the Home log is empty). Re-sign and install using **SideStore, AltStore, Feather, Sideloadly, Impactor, or iLoader** with App Group entitlements enabled.

### 2. Fast Clean Up works, why do High-Quality Clean Up, Extend, Reframe, or Camera `SIRI` fail?
- **If it fails instantly in 0ms (no loading spinner)**:
  - On all native Apple Intelligence iPhones (`iPhone 15 Pro` and newer), factory `CacheData` requires **`Personal Translator` (slot `#266`) = `true`** and **`Audio Intelligence` (slot `#178`) = `false`**. Earlier versions (`v0.8.3 – v0.8.5`) could flip `#266` to `false`, causing `GenerativeModels / ModelCatalog` to abort locally in 0ms.
  - **Fix**: Update to **`v0.9.1+`** → open **Tweaks → MobileGestalt** → tap **One-Click Setup / Repair** → **Apply** → **power off and cold-reboot**.
- **If it fails on `iOS 27.0 – 27.2.1` (`PrivateCloudComputeError Code=32033` / `QUIC-BLOCK` / `Code=1009`)**:
  - **Cause 1 — Incomplete PCC routing (`Code=32033`)**: Generic AI rule lists typically cover only `apple-relay.*` while omitting Apple's blind-signature token issuers and generative gateways (`*.issuer.apple.com`, `ropes.apple.com`, `mask-api.icloud.com`, `mask.icloud.com`, `mask-h2.icloud.com`, `*.app.apple.com`), letting catch-all `Apple_All` / `GEOSITE,apple` rules leak them over `DIRECT` and triggering an immediate `32033` rejection.
  - **Cause 2 — Blocked UDP 443 (`QUIC-BLOCK`)**: PCC OHTTP relies on UDP 443 (`QUIC`). Ensure UDP is open on your US proxy server firewall and not blocked by QUIC reject rules.
  - **One-Stop Fix via [AppleFlow](https://github.com/Kianuni/AppleFlow)**: Install the complete zero-MitM module or rule-set from **[AppleFlow Web Studio](https://kianuni.github.io/AppleFlow/)** (supports Surge, Loon, Shadowrocket, Stash, Mihomo/OpenClash, Quantumult X, Sing-box + local Config Doctor), tap **Update External Resources** in your proxy client, and **reboot your iPhone once** to clear `privatecloudcomputed`'s cached `32033 / 1009` backoff state.
  - ⚠️ **Rate-limit cooldown note (`Code=1009`)**:
    1. **Local cached cooldown** (`retry-after` in `privatecloudcomputed`): cleared by rebooting once.
    2. **Server-side quota** (`Code=1009 "Rate limited"` after reboot): wait a few hours up to ~24 hours without spamming retries. Fast (on-device) Clean Up is unaffected.

- **iOS 27.3 beta on China (`CH/A`) hardware: all slots correct, network fine, still fails**:
  - iOS 27.3 beta 1 added a China-specific AI policy branch. If Photos' local eligibility check (`GenerativeFunctionsFoundation`) detects `CH` hardware from any source, it looks up a "CN region policy" that Apple hasn't published yet, so the request is blocked **before any network traffic**. Log signature: `Eligibility returned no CN region policy on a CH region code device`. The check does not read MobileGestalt's cached `RegionCode` (it triggers even when the Inspector shows `LL`), so **MobileGestalt edits cannot bypass it**. Do not inject uncached keys, which triggers a cache reset at boot. Confirmed in [#13](https://github.com/Kianuni/Erosion-CN/issues/13), [#22](https://github.com/Kianuni/Erosion-CN/issues/22), [#28](https://github.com/Kianuni/Erosion-CN/issues/28).
  - **Fix**: return to **iOS 27.2.x** if Apple still signs it (27.2.1 has no such check). Run **One-Tap Factory Restore** (or **Clean Cache Rebuild**) and back up to a computer first; a 27.3 backup cannot be restored onto 27.2.1. Or stay on 27.3 beta and wait for Apple to change it. Siri chat, Writing Tools, and Camera Control Visual Intelligence (OpenAI / Google) are unaffected.
- **How to tell them apart**: on a Mac, reproduce the error once, run `sudo log collect --device --last 5m --output ~/Desktop/pcc.logarchive`, then `log show ~/Desktop/pcc.logarchive --style compact --predicate 'process == "privatecloudcomputed" OR process == "modelmanagerd" OR process == "Photos"' | grep -E "1009|Rate limited|region policy|InferenceError"`. `1009` means rate limit; `no CN region policy` means the 27.3 beta check.

### 3. About shows `LL/A`, why haven't Apple Intelligence, Siri, or `Add eSIM` appeared yet?
1. **Cold Reboot required**: Binary `CacheData` changes (`green-tea = false`) require a **full manual power-off and reboot** (Respring is not enough). Verify in **Live Inspector** that `green-tea` live value is `false (Bool)`.
2. **System Region & Geo-Eligibility**: Change **Settings → General → Language & Region → Region** away from `China mainland` (e.g. `Taiwan` or `United States`) and route `gspe1-ssl.ls.apple.com` through a US proxy so `eligibilityd` refreshes. For ready-to-use zero-MitM routing modules, rule-sets, and a local Config Doctor, see companion project **[AppleFlow](https://github.com/Kianuni/AppleFlow)** ([Web Studio](https://kianuni.github.io/AppleFlow/)).
3. **Use a non-China App Store account**: On Mainland China devices, Apple Intelligence eligibility also depends on the Apple Account country. If **Settings → [your name] → Media & Purchases** is still a China mainland account, the Apple Intelligence menu may not appear or finish activating. Switch Media & Purchases to an overseas account (your iCloud account can stay as-is). Thanks to @Chinsin in [#20](https://github.com/Kianuni/Erosion-CN/issues/20).
4. **`Add eSIM` on Mainland `iPhone 18 Pro / Pro Max` (`A3715` / `A3718`)**: Eject the dual physical SIM tray first and cold-reboot with an **empty SIM tray** so baseband exposes `Add eSIM`; once your overseas eSIM is provisioned, re-insert your physical SIM.

### 4. Important Safety Reminder Before iOS Updates / Downgrades
- `worse_query` currently supports **iOS 27.0 – 27.2.1** and **27.3 beta 1** only — disable automatic iOS updates.
- Always run **One-Tap Factory Restore** (or **Clean Cache Rebuild**) inside Erosion **before** flashing, restoring, or downgrading iOS.

---

## Related Open-Source Projects (Kianuni Ecosystem)

If you find **Erosion-CN** helpful, check out our other open-source iOS tools:

| Project | Description | Highlights |
| :--- | :--- | :--- |
| **[AppleFlow](https://github.com/Kianuni/AppleFlow)** | Zero-MitM routing for Apple Intelligence, PCC, and Siri, paired with a local **[Web Config Doctor & Probe](https://kianuni.github.io/AppleFlow/)** | Surge / Loon / Shadowrocket / Stash / Mihomo / QX / Sing-box |
| **[WQGuard](https://github.com/Kianuni/WQGuard)** | 100% read-only iOS sandbox escape scanner, sideloaded IPA auditor & firmware CVE guard | iOS / iPadOS 26.2+ – 27.x security auditing |
| **[Camlo](https://github.com/Kianuni/Camlo)** | Bring your iPhone lock screen to life: computer-free slide-to-unlock animations, glasses-free 3D & live wallpapers | iOS / iPadOS 26 – 27 lock screen customization |
| **[Enkard](https://github.com/Kianuni/Enkard)** | Purely offline, zero-cloud encrypted iPhone card vault bound to Apple Secure Enclave hardware | Bank-grade local storage for sensitive cards & credentials |

---

## Credits & License

- Upstream project: **[jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion)** (`lunginspector`, `forcequit`, `0xjohnny`, `Skadz`, `rooootdev`, `neonmodder123`)
- Exploit: **[forcequitOS/worse_query](https://github.com/forcequitOS/worse_query)**
- References & Special Thanks: `huamidev (GestaltX)`, `kolbicz (WQFiles)`, `KirbySD`, `PoomSmart (MGKeys)`
- Licensed under **[GPLv3](./LICENSE)**.

---

## Star History

<div align="center">
  <a href="https://star-history.com/#Kianuni/Erosion-CN&Date">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Kianuni/Erosion-CN&type=Date&theme=dark" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Kianuni/Erosion-CN&type=Date" />
      <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Kianuni/Erosion-CN&type=Date" width="680" />
    </picture>
  </a>
</div>
