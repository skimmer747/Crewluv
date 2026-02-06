# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CrewLuv is a SwiftUI iOS app (iOS 17.0+) that allows pilots' partners and family members to track their real-time status via CloudKit sharing. The app receives read-only status updates from the Duty pilot scheduling app through a dedicated CloudKit zone.

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

#### Status Management (`Services/PartnerStatusReceiver.swift`)
- Fetches pilot status from shared CloudKit zone
- Auto-refresh every 2 minutes
- Handles CloudKit sync timing with retry logic

#### Data Model (`Models/SharedPilotStatus.swift`)
- Privacy-conscious: excludes crew names, hotel details, pay info
- CloudKit-optimized struct (not SwiftData)
- Includes flight info, location, timers, and trip progress

### App Flow
1. **Onboarding**: User accepts CloudKit share link from pilot
2. **Share Processing**: `CloudKitShareManager` handles share acceptance
3. **Status Sync**: `PartnerStatusReceiver` fetches and displays pilot status
4. **Auto-refresh**: Status updates every 2 minutes

## File Structure

```
Crewluv/
├── App/                      # App lifecycle and URL handling
│   └── CrewluvApp.swift     # Main entry point with CloudKit share URLs
├── Views/                    # SwiftUI views by feature
│   ├── Welcome/             # Onboarding screens
│   └── Status/              # Status display
├── Models/                   # Data models
│   └── SharedPilotStatus.swift
├── Services/                 # Business logic
│   ├── CloudKitShareManager.swift    # CloudKit share operations
│   └── PartnerStatusReceiver.swift   # Status fetching
└── Utils/                    # Utilities
    └── DebugLog.swift       # DEBUG-only logging
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
3. CrewLuv accepts share and stores zone owner
4. App fetches status from shared zone

## Testing Strategy

- Unit tests in `CrewluvTests/`
- UI tests in `CrewluvUITests/`
- CloudKit sharing can be tested with iOS Simulator
- Debug logging available in DEBUG builds via `DebugLog.swift`

## Dependencies

- **iOS 17.0+** required
- **CloudKit** for data sharing
- **SwiftUI** for UI
- **No external package dependencies**

## Adding New Features

### New View
Create in appropriate feature directory under `Views/[FeatureName]/`

### New Service
Add to `Services/` directory following existing patterns

### New Model
Add to `Models/` directory, consider CloudKit compatibility

## Privacy and Security

- Only essential flight information is shared
- No crew names, hotel details, or pay information
- One-way sync (CrewLuv is read-only)
- CloudKit handles authentication and sharing permissions