# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. **All code must read as if written by a senior Apple engineer — idiomatic Swift, precise API usage, and uncompromising adherence to Apple's Human Interface Guidelines and platform conventions.**

## Code Quality Standards — Non-Negotiable

### Swift Language Rules
- Write **modern, idiomatic Swift**. Use the latest Swift language features available for our deployment target (iOS 17.0+).
- Prefer `let` over `var`. Default to immutability. Every `var` must justify its existence.
- Use **value types** (`struct`, `enum`) over reference types (`class`) unless you need identity, inheritance, or reference semantics.
- Use Swift's type system aggressively: `enum` with associated values over stringly-typed data, `Result` types, strong typedefs via wrapper structs when disambiguation matters.
- Use **guard** for early exits. Never nest deeply — flat code reads better.
- Prefer `if let` / `guard let` shorthand (Swift 5.7+). Never force-unwrap (`!`) unless the invariant is provable and documented.
- Use trailing closure syntax. Use implicit `return` for single-expression closures and computed properties.
- Prefer `[weak self]` with `guard let self` in closures that capture `self` on reference types.
- Use **Access Control** intentionally: `private` by default, `internal` only when needed across files in the module, never `public`/`open` unless building a framework API.
- Follow **Swift API Design Guidelines** exactly: clarity at the point of use, fluent English phrasing, no abbreviations, argument labels that read as grammar (e.g., `insert(_:at:)`, `distance(from:to:)`).
- Name booleans as assertions: `isLoading`, `hasAccepted`, `shouldRefresh` — never `loading`, `accepted`, `refresh`.
- Use `// MARK: -` to organize file sections. Group lifecycle, public API, private helpers, and protocol conformances.

### SwiftUI Rules
- Build views as **small, composable, single-responsibility** structs. Extract subviews aggressively — no view body should exceed ~30 lines.
- Use `@State` for local/transient state, `@Binding` for parent-owned state, `@Environment` for dependency injection, `@Observable` (iOS 17+) for shared mutable models.
- Never put business logic in views. Views describe **what**, not **how**. All logic belongs in models, services, or dedicated view models.
- Use `.task {}` for async work on view appearance. Prefer structured concurrency (`async/await`, `TaskGroup`) over callbacks or Combine.
- Prefer Apple's built-in components (`List`, `NavigationStack`, `Sheet`, `Alert`) over custom reimplementations. Match system behavior before customizing.
- Use **SF Symbols** for iconography. Use system semantic colors (`Color.primary`, `.secondary`, `.accentColor`) and dynamic type (never hardcoded font sizes) unless design requires it.
- Support **Dark Mode**, **Dynamic Type**, and **accessibility** out of the box. Use `.accessibilityLabel()`, `.accessibilityHint()`, and `.accessibilityValue()` on all interactive elements.
- Animations should use **spring-based** timing (`.spring()`, `.snappy`, `.bouncy`) or `.default` — never arbitrary durations unless matching a specific motion spec. Keep animations subtle and purposeful.

### Apple Human Interface Guidelines
- Follow the [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/) at all times.
- Respect **safe areas**, **layout margins**, and system spacing. Never hardcode padding/margin values when system defaults exist.
- Use **standard navigation patterns**: `NavigationStack` for hierarchical content, `TabView` for top-level sections, modal sheets for focused tasks.
- Confirmation dialogs for destructive actions. Swipe-to-delete should use `.destructive` role.
- Error states must be user-friendly — no raw error messages, technical jargon, or stack traces shown to users. Provide recovery actions.
- Empty states should be helpful, not blank. Tell the user what to do next.
- Loading states must be present and use appropriate indicators (skeleton views, `ProgressView`).

### Concurrency & Performance
- Use **Swift Concurrency** (`async`/`await`, `actor`, `@Sendable`) exclusively. No completion handlers in new code. No Combine unless interfacing with APIs that require it.
- Mark classes that manage mutable shared state as `actor` or use `@MainActor` appropriately.
- All UI updates on `@MainActor`. Never dispatch to main queue manually — use `@MainActor` annotation instead.
- Avoid blocking the main thread. Long operations (network, disk, parsing) must be async.
- Use `Task` with proper cancellation handling. Check `Task.isCancelled` in loops.

### Error Handling
- Use typed `throws` when the error set is known. Use `do`/`catch` with pattern matching on specific errors before catching generically.
- Log errors with context via `DebugLog`. Never silently swallow errors — at minimum log them.
- CloudKit errors should be handled with specific `CKError.Code` matching (`.networkFailure`, `.zoneBusy`, `.userDeletedZone`, etc.).
- Present user-facing errors with clear language and actionable next steps.

### Code Structure
- One primary type per file. The file name matches the type name.
- Extensions for protocol conformances go in the same file unless the conformance is substantial.
- Keep files under ~300 lines. If a file grows beyond that, decompose it.
- Group related functionality in `// MARK: -` sections within files.

## Project Overview

CrewLuve is a SwiftUI iOS app (iOS 17.0+) that allows pilots' partners and family members to track their real-time status via CloudKit sharing. The app receives read-only status updates from the Duty pilot scheduling app through a dedicated CloudKit zone.

## Development Commands

### Build and Run
```bash
# Open project in Xcode
open Crewluv.xcodeproj

# Build from command line
xcodebuild -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Code Organization
Use Xcode for all development tasks. The project follows iOS development conventions with clean separation of concerns.

## Architecture

### Core Design Pattern
- **Service Layer Pattern**: Business logic separated into dedicated service classes
- **CloudKit Sharing**: Uses `PartnerBeaconZone` for one-way data sync from Duty app
- **Feature-Based Structure**: Views organized by feature area (Welcome, Status) rather than by type

### Key Components

#### CloudKit Integration (`Services/CloudKitShareManager.swift`)
- Handles CloudKit share acceptance from URL links
- Manages zone owner persistence in UserDefaults
- Container ID: `iCloud.com.toddanderson.duty`
- Zone: `PartnerBeaconZone`

#### Status Management (`Services/PilotStatusSource.swift`)
- The one place that reads the pilot's status, whoever asks: the screen, a push or the background refresh
- Reads Crewlu Cloud's partner door once this device is connected there (`Services/PartnerCloud/`), and the shared CloudKit zone otherwise
- Hands each new status to the alerts (`StatusChangeNotifier`) once
- `PartnerStatusReceiver` is the screen's model: it shows how every read went
- Refreshes on coming to the front, on pull-to-refresh and the refresh button, on silent pushes, in the background refresh, and every 60 seconds while in front on Crewlu Cloud

#### Alerts (`Services/StatusChangeNotifier.swift`, `CrewluveAlerts/`)
- `StatusChangeNotifier` compares each new status with the last one and keeps its snapshot. It names each alert by its kind, in `AlertWording`'s words, with the same rules as Crewlu Cloud's partner-push: the shared cases in `CrewluvTests/Fixtures/PartnerSummary/alert-cases.json` hold both to them
- On iCloud the app posts its own alerts. On Crewlu Cloud they come as alert pushes once Crewlu Cloud has accepted this device's push registration (`AlertPushes`). Until then, and for a read a hidden push asked for, the app posts its own
- An alert push carries only its kind. The helper target, `CrewluveAlerts` (a notification service extension), reads the status with this device's key and writes the kind's words, or a plain line (`AlertPushWriter`). It builds 15 of the app's files through Target Membership, reads the key from Crewluve's own Keychain group, and only reads
- The helper's 15 files must stay safe in an app extension and compile with only each other: a file one of them comes to need joins the helper too (tick `CrewluveAlerts` in its Target Membership)
- The app keeps its Keychain items in its own app ID's group, the helper's one group. Don't give the app a `keychain-access-groups` entitlement unless that group stays first, or new items land where the helper can't read them

#### Connecting (`App/LinkRouter.swift`, `Services/PartnerJoiner.swift`)
- `LinkRouter` takes every link the app is given, and the welcome screen's paste box: Crewluve's own `https://crewluve.crewlu.net/join#t=…` and `#c=…` links (`PartnerLink`) go to the joiner, and iCloud share links to `CloudKitShareManager`
- `PartnerJoiner` joins Crewlu Cloud with an invite link or a 6-character code from another device, asking first when the link is from another pilot
- `CrewluCloudDevice` (`Services/PartnerCloud/`) is this device on Crewlu Cloud: its key, joining with a pending key, switching, Disconnect and hand-off codes. Each switch and each forget moves its generation on, so an answer for a key the device has let go of changes nothing
- Logs show Crewluve's links only by host and path: what follows the `#` is a secret

#### Data Model (`Models/SharedPilotStatus.swift`)
- Privacy-conscious: excludes crew names, hotel details, pay info
- CloudKit-optimized struct (not SwiftData)
- Includes flight info, location, timers, and trip progress

### App Flow
1. **Onboarding**: User taps the pilot's invite link, or types a code from another of their devices, and `PartnerJoiner` connects to Crewlu Cloud. A pilot on an older CrewLu sends a CloudKit share link instead
2. **Share Processing**: `CloudKitShareManager` handles a CloudKit share's acceptance
3. **Status Sync**: `PilotStatusSource` reads the pilot's status, and `PartnerStatusReceiver` displays it
4. **Refresh**: On coming to the front, pull-to-refresh and the refresh button, silent pushes, the background refresh, and every 60 seconds while in front on Crewlu Cloud

## File Structure

```
Crewluv/
├── App/                      # App lifecycle and URL handling
│   ├── CrewluvApp.swift     # Main entry point
│   └── LinkRouter.swift     # Where each opened or pasted link goes
├── Views/                    # SwiftUI views by feature
│   ├── Welcome/             # Onboarding screens
│   └── Status/              # Status display
├── Models/                   # Data models
│   └── SharedPilotStatus.swift
├── Services/                 # Business logic
│   ├── CloudKitShareManager.swift    # CloudKit share operations
│   ├── PilotStatusSource.swift       # Reads the status, from Crewlu Cloud or iCloud
│   ├── PartnerStatusReceiver.swift   # The status screen's model
│   ├── PartnerJoiner.swift           # Joining with an invite link or a code
│   └── PartnerCloud/                 # Crewlu Cloud's partner door, and this device on it
└── Utils/                    # Utilities
    └── DebugLog.swift       # DEBUG-only logging
CrewluveAlerts/               # The alert pushes' helper, a notification service extension
└── NotificationService.swift # Writes each alert push's words with the app's AlertPushWriter
```

## CloudKit Configuration

### Container Setup
- Container: `iCloud.com.toddanderson.duty`
- Database: Shared CloudKit database
- Zone: `PartnerBeaconZone` (shared from Duty app)
- Record Type: `SharedPilotStatus`

### Share Workflow
1. Pilot creates share in Duty app
2. Partner receives share URL (iMessage/manual)
3. CrewLuve accepts share and stores zone owner
4. App fetches status from shared zone

## Testing Strategy

- Unit tests in `CrewluvTests/`. The helper target has none of its own: its logic is `AlertPushWriter`, in the app's folder, which `CrewluvTests` tests
- UI tests in `CrewluvUITests/`
- CloudKit sharing can be tested with iOS Simulator
- Debug logging available in DEBUG builds via `DebugLog.swift`
- Test naming: `test_<methodOrBehavior>_<scenario>_<expectedResult>()`
- Prefer `XCTAssertEqual` over `XCTAssertTrue` for better failure messages

## Dependencies

- **iOS 17.0+** required
- **CloudKit** for data sharing
- **SwiftUI** for UI
- **No external package dependencies** — prefer Apple frameworks. Only add a third-party dependency if it solves a problem no Apple API addresses and the maintenance burden is justified.

## Adding New Features

### New View
Create in appropriate feature directory under `Views/[FeatureName]/`. Decompose into small subviews. Ensure Dark Mode and Dynamic Type support from the start.

### New Service
Add to `Services/` directory following existing patterns. Use `actor` for services that manage mutable state. Expose async APIs.

### New Model
Add to `Models/` directory. Use `struct` with `Sendable` conformance. Consider CloudKit compatibility. Validate data at the boundary, trust it internally.

## Privacy and Security

- Only essential flight information is shared
- No crew names, hotel details, or pay information
- One-way sync (CrewLuve is read-only)
- CloudKit handles authentication and sharing permissions
