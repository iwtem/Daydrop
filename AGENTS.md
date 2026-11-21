# AGENTS.md — 知时 · Daydrop

This document defines the architecture, conventions, build/test commands, and **end-to-end release + real-time push workflow** for AI coding agents working on **Daydrop (知时)**.

---

## 1. Project Overview

**Daydrop (知时)** is a minimalist native macOS menu-bar calendar & desktop widget app (macOS 14.0+, SwiftUI + AppKit + WidgetKit) focused on dates, China statutory holidays & make-up workdays, 24 solar terms, and the Chinese lunar calendar.

### Key Architectural Decisions (Do Not Break)
- **Menu-Bar Only (`LSUIElement = true`)**: The app never appears in the Dock. It resides in the macOS menu bar and can expand into a standalone resizable window (Month / Year view).
- **Main App vs. Widget Sandbox Split**:
  - `Daydrop/Daydrop.entitlements`: **Non-sandboxed** (`<dict/>`) intentionally so `AppUpdater` can atomically replace `/Applications/Daydrop.app` and relaunch in-app. **Do NOT re-enable `app-sandbox` on the main app.**
  - `DaydropWidget/DaydropWidget.entitlements`: **Sandboxed** (`app-sandbox = true`) with `com.apple.security.temporary-exception.shared-preference.read-write` for domain `com.daydrop.shared`. **Do NOT remove this domain**, as it enables real-time preference & holiday-cache sync between the main app and desktop widgets without requiring a paid Apple Developer Team / provisioning profile.
- **State Management**: Prefer `ObservableObject` + `@Published` over Swift `@Observable` macros to ensure reliable compilation across restricted/sandboxed build environments.
- **Bilingual Support (`L10n`)**: All user-facing strings (main app, widgets, holidays, solar terms, lunar descriptions, settings) MUST be localized in `Shared/Localization/L10n.swift` for both Simplified Chinese (`zh-Hans`) and English (`en`), defaulting to macOS system language.
- **Dynamic Theming**:
  - All accent colors MUST come from `ThemePalette` (`Shared/Theme/DaydropTheme.swift`), never hardcoded system blue or static colors.
  - Use `ThemedSwitchToggleStyle`, `ThemedSegmentedControl`, and `ThemedAppIconView` (`Daydrop/Views/ThemedControls.swift`) for controls that AppKit would otherwise lock to system accent blue.
- **Desktop Widget Vibrant Mode**:
  - Every WidgetKit view (`Small` / `Medium` / `Large`) MUST check `@Environment(\.widgetRenderingMode)` and avoid opaque solid fills with white text when `renderingMode != .fullColor` (macOS frosted glass / vibrant desktop mode turns both solid fills and white text into white-on-white).

---

## 2. Repository Structure & Project Generation

```text
Daydrop/
├── Shared/                      # Compiled into BOTH Daydrop and DaydropWidget
│   ├── CalendarEngine/          # Astronomical 24 solar terms, lunar engine, grid generator
│   ├── HolidayData/             # HolidayStore + bundled holidays_cn.json (2024–2027)
│   ├── Localization/            # L10n bilingual engine (zh-Hans / en)
│   ├── Settings/                # AppPreferences (shared via com.daydrop.shared)
│   └── Theme/                   # 5 bright flat ThemePalettes
├── Daydrop/                     # Main macOS menu-bar app
│   ├── Updater/                 # AppUpdater (GitHub Releases) + UpdatePushListener (SSE)
│   ├── Views/                   # Popover, Expanded Window, Year View, Settings, ThemedControls
│   └── Window/                  # NSWindow configurator & popover dismissal helpers
├── DaydropWidget/               # WidgetKit extension (Small / Medium / Large)
├── DaydropTests/                # XCTest unit tests
├── .github/workflows/           # notify-release.yml (auto SSE push on GitHub Release)
└── scripts/
    ├── generate_xcodeproj.py    # Deterministic Xcode project generator
    ├── generate_icons.swift     # Vector renderer for AppIcon & MenuBarIcon
    └── release.sh               # One-command build, test, GitHub Release & SSE push
```

### Adding New Source Files
**Never hand-edit `Daydrop.xcodeproj/project.pbxproj`.**
Whenever you add or remove a `.swift` or resource file:
1. Update the file list in `scripts/generate_xcodeproj.py` (`SHARED_SWIFT`, `APP_SWIFT`, `WIDGET_SWIFT`, or `TEST_SWIFT`).
2. Regenerate the Xcode project:
   ```bash
   python3 scripts/generate_xcodeproj.py
   ```

### Regenerating Icons
AppIcon (`AppIcon.appiconset`) and MenuBarIcon (`MenuBarIcon.imageset`, 20pt template image) are vector-generated:
```bash
swift -module-cache-path /tmp/swift_module_cache scripts/generate_icons.swift
```

---

## 3. Local Build & Test Commands

The project uses local ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Manual`), so it builds and tests out of the box without a paid Apple Developer account.

### Run Unit Tests (Required Before Every Release)
```bash
xcodebuild \
  -project Daydrop.xcodeproj \
  -scheme Daydrop \
  -configuration Debug \
  -derivedDataPath /tmp/DaydropDerivedData \
  test
```

### Build Universal Release App (`arm64` + `x86_64`)
```bash
xcodebuild \
  -project Daydrop.xcodeproj \
  -scheme Daydrop \
  -configuration Release \
  -derivedDataPath /tmp/DaydropReleaseBuild \
  build
```

---

## 4. Release & Real-Time Push Workflow (CRITICAL)

Running instances of **Daydrop** maintain a persistent SSE connection to `ntfy.sh` (`https://ntfy.sh/daydrop-iwtem-releases-7f3a9c2e/sse`). When a release signal arrives, clients immediately verify the latest official release via `https://api.github.com/repos/iwtem/Daydrop/releases/latest`, silently download & verify the `.zip` asset in the background, and prompt the user to click **Restart & Update**.

### Option A: One-Command Release Script (Preferred)
After committing your feature changes on `main`:
```bash
./scripts/release.sh <VERSION> "<Release notes>"
# Example:
./scripts/release.sh 1.2.2 "优化小组件显示并修复已知问题"
```

### Option B: Manual / Step-by-Step Release (When Running Commands Individually)
Follow **every** step in exact order:

1. **Bump version in BOTH Info.plists** (`CFBundleShortVersionString` = `<VERSION>`, increment `CFBundleVersion` by 1):
   - `Daydrop/Info.plist`
   - `DaydropWidget/Info.plist`
2. **Run all unit tests** (`xcodebuild ... test`) and confirm **0 failures**.
3. **Build Universal Release** (`xcodebuild ... -configuration Release build`).
4. **Package `.zip` with `ditto`** (MUST use `ditto`, NOT `zip`, to preserve macOS bundle structure, code signatures, and `DaydropWidget.appex`):
   ```bash
   mkdir -p dist
   rm -rf dist/Daydrop.app "dist/Daydrop-v<VERSION>-macOS.zip"
   ditto /tmp/DaydropReleaseBuild/Build/Products/Release/Daydrop.app dist/Daydrop.app
   ditto -c -k --sequesterRsrc --keepParent dist/Daydrop.app "dist/Daydrop-v<VERSION>-macOS.zip"
   ```
   > Asset naming MUST end in `.zip` (convention: `Daydrop-v<VERSION>-macOS.zip`). `dist/` is git-ignored — **never commit binaries to git**.
5. **Commit & push `main`** to `origin` (`git@github.com:iwtem/Daydrop.git`).
6. **Publish GitHub Release** (tag MUST be `v<VERSION>`):
   ```bash
   gh release create "v<VERSION>" "dist/Daydrop-v<VERSION>-macOS.zip" \
     --repo iwtem/Daydrop \
     --title "知时 · Daydrop v<VERSION>" \
     --notes "<Release notes>"
   ```
7. **Broadcast real-time SSE update signal** (so running apps pick it up in 1–2 seconds without waiting for GitHub Actions runner startup; `.github/workflows/notify-release.yml` also fires automatically as backup):
   ```bash
   curl -fsS -H "Title: Daydrop Release" -d "v<VERSION>" "https://ntfy.sh/daydrop-iwtem-releases-7f3a9c2e"
   ```

---

## 5. UX Guardrails
- Keep the UI clean and distraction-free: no schedules/events, no ads, no redundant text chrome.
- Menu bar shows icon only on ordinary days; shows festival / solar-term name automatically on matching days.
- Menu bar popover: no decorative top color bar, no bottom footer row; Expand / Settings / Quit (`power` icon) live cleanly in the top-right header with **no hover tooltips**, and clicking Expand or Settings must dismiss the popover immediately.
- Expanded window: single hairline separator (`hideTitlebarSeparator: true`), Month/Year segmented control flush right, no Pin/Settings icons in the expanded toolbar.
- Never force-quit the user's running app after downloading an update; always stage it and wait for the user to click **Restart & Update**.
