# Locibin

Offline-first iPhone app for organizing stored things — garage, pantry, basement, closets.
Every storage location (shelf, drawer, box, cabinet) gets a QR label; scanning it shows what is inside,
and search shows the full path to any item, e.g. `Garage › Rack 2 › Box 3 › Bosch drill`.

`Locibin` is the project / target name. The App Store name is chosen later.

## Requirements

- Xcode 16 or newer (the project uses folder-synchronized groups); developed with Xcode 27.1
- iOS 18.0+ deployment target, iPhone only, portrait
- Swift 6 language mode, default actor isolation `MainActor`
- No third-party dependencies, no backend, works fully offline

## Build and test

```bash
xcodebuild -project Locibin.xcodeproj -scheme Locibin \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

Run the same tests on an iOS 26+ simulator as well — both looks (iOS 18 and Liquid Glass) are supported.

The scheme runs two test targets:

- `LocibinTests` — unit tests (Swift Testing) for services and ViewModels, on in-memory stores.
- `LocibinUITests` — end-to-end flows and Apple's accessibility audit (`performAccessibilityAudit`).
  The app is launched with `--ui-testing` (empty in-memory store, real data is never touched) and in English.

Tip: `xcodebuild test` clones and may shut down the simulator it runs on — keep a different simulator for manual checks.

Signing: set your team in *Signing & Capabilities* before running on a device. Simulator builds need no team.

## Project layout

Files and folders inside `Locibin/` and `LocibinTests/` are picked up by Xcode automatically
(synchronized folders) — no need to add them to the project manually.

```
Locibin/
  App/            entry point, AppRouter, AppDependencies, ModelContainer
  Models/         SwiftData models and schema versions
  Services/       InventoryService, QRCodeService, LabelPDFRenderer, BackupService
  Features/       one folder per screen: <Name>View.swift + <Name>ViewModel.swift
  DesignSystem/   shared buttons, tiles, empty states, color tokens
  Resources/      Assets.xcassets, Localizable.xcstrings
LocibinTests/     Swift Testing unit tests
LocibinUITests/   XCTest UI tests and accessibility audit
Config/           partial Info.plist (URL scheme, backup file type)
```

Folders other than `App/` and `Resources/` are created together with their first file.

## Architecture rules (MVVM + services)

- **View** — layout, bindings and forwarding user actions to its ViewModel. No business logic, no data access, no `@Query`.
- **ViewModel** — one `@Observable` per screen: screen state, display-ready data, form drafts, validation, calls to services and the router.
- **Services** — rules shared by several screens (moving, deleting, QR, PDF, backup). They know nothing about UI.
- **AppRouter** — navigation stack, sheets and deep links.
- All user-facing strings live in `Localizable.xcstrings` (English source, Russian translation).
- Secondary text uses `Color.secondaryText` and list headers use `SectionHeader` (the system secondary style fell just under the 4.5:1 contrast target).
- Empty and error states are wrapped in `ScrollableFullScreen` so buttons stay reachable at the largest text sizes.

## Fixed identifiers — do not change after release

| What | Value |
|---|---|
| Bundle ID | `com.diasiosdev.locibin` |
| QR / URL scheme | `com.organizestorage://location/<uuid>` |
| Backup UTType / extension | `com.organizestorage.backup` / `.storagebackup` |
