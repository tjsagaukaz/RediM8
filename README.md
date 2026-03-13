# RediM8

RediM8 is a dark-mode-first, offline-first iPhone app for emergency preparedness and response.

It is designed to feel like a serious operating system for when infrastructure fails: fast to scan, trustworthy under stress, and practical for real-world Australian emergency scenarios.

## What RediM8 does

- `Home`: command-center dashboard for emergency mode, official alerts, next actions, and readiness overview
- `Plan`: household and vehicle readiness planning, go-bag tracking, and staged evacuation prep
- `Vault`: secure local document storage for emergency essentials
- `Library`: offline field guides and reference content
- `Map`: tactical offline map experience powered by MapLibre
- `Signal`: local assistive comms and nearby reporting

Core safety tooling stays available without turning the product into a social app, gaming UI, or gimmicky concept piece.

## Product Principles

- Offline-first emergency readiness
- Clear, action-first hierarchy
- Dark mode primary experience
- High readability in stressful conditions
- Premium, cinematic visual identity without sacrificing trust
- Local-first handling for sensitive vault content

## Tech Stack

- SwiftUI
- iOS 17+
- Swift 5.10
- Xcode project plus `project.yml` for XcodeGen-based project maintenance
- [MapLibre Native Distribution](https://github.com/maplibre/maplibre-gl-native-distribution) for map rendering
- SQLite-backed local storage for app data

## Getting Started

### Requirements

- Xcode with iOS 17 SDK support
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) `2.45.0+` if you want to regenerate the project from `project.yml`

### Build in Xcode

1. Open `RediM8.xcodeproj`
2. Select the `RediM8` scheme
3. Choose an iPhone simulator or connected iPhone
4. Build and run

### Build from Terminal

```bash
xcodebuild -project RediM8.xcodeproj -scheme RediM8 -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### Regenerate the Xcode Project

If you make structural changes in `project.yml`:

```bash
xcodegen generate
```

## Running Tests

```bash
xcodebuild test -project RediM8.xcodeproj -scheme RediM8 -destination 'platform=iOS Simulator,name=iPhone 16'
```

If that simulator is not available on your machine, swap in any installed iPhone simulator.

## Repository Layout

```text
RediM8/
├── RediM8/                 App source
│   ├── App/
│   ├── Core/
│   ├── Features/
│   ├── Models/
│   ├── Services/
│   ├── Utilities/
│   └── Views/
├── RediM8Tests/            Unit tests
├── RediM8.xcodeproj/       Xcode project
├── project.yml             XcodeGen definition
├── icons/                  Source icons and generated previews
├── map_markers/            Source marker artwork
└── tools/                  Asset generation scripts
```

## Suggested Git Workflow

- Keep `main` stable
- Do feature and fix work in short-lived branches, for example `codex/home-polish` or `codex/vault-followups`
- Open pull requests for review tooling like GitHub Copilot or external model review
- Tag milestones when you hit release checkpoints

## Current Status

The app includes:

- onboarding and emergency quick actions
- polished premium UI shell with cinematic hero panels
- command dock navigation
- readiness planning and reporting
- secure vault flows
- offline guides, maps, and signal tooling

## Notes

- This repository is intended to stay practical and production-oriented. Preserve emergency clarity first.
- Large visual changes should keep the current architecture, hero imagery system, and command-center feel intact.
