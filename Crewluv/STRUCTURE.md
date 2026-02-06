# CrewLuv Project Structure

This document describes the scalable file organization used in CrewLuv.

## Directory Structure

```
Crewluv/
├── App/                          # Application lifecycle and configuration
│   └── CrewluvApp.swift         # Main app entry point, URL handling, share acceptance coordination
│
├── Views/                        # All SwiftUI views organized by feature
│   ├── Welcome/                 # Onboarding and welcome screens
│   │   └── ContentView.swift   # Main view coordinator (loading, welcome, status display)
│   │
│   └── Status/                  # Status display screens
│       └── PilotStatusView.swift # Pilot status display with cards and timers
│
├── Models/                       # Data models and domain objects
│   └── SharedPilotStatus.swift  # CloudKit-backed pilot status model
│
├── Services/                     # Business logic and external integrations
│   ├── CloudKitShareManager.swift    # CloudKit share acceptance service
│   └── PartnerStatusReceiver.swift   # Fetches and manages pilot status updates
│
└── Utils/                        # Utilities and helpers
    └── DebugLog.swift           # Debug logging utility (DEBUG-only)
```

## Design Principles

### 1. Feature-Based Organization
Views are organized by feature area (Welcome, Status) rather than by type. This makes it easy to:
- Find related components quickly
- Add new features without cluttering existing directories
- Maintain clear boundaries between features

### 2. Service Layer Pattern
Business logic is separated into service classes:
- `CloudKitShareManager` - Handles all CloudKit share operations
- `PartnerStatusReceiver` - Manages status fetching and auto-refresh

### 3. Clear Separation of Concerns
- **App/** - App lifecycle, URL handling, configuration
- **Views/** - Pure UI, minimal business logic
- **Models/** - Data structures and domain objects
- **Services/** - Business logic, API integration, data management
- **Utils/** - Reusable helpers and utilities

## Adding New Features

### Adding a New View
```
Views/
└── [FeatureName]/
    ├── [FeatureName]View.swift      # Main view
    ├── [FeatureName]Card.swift      # Optional subviews
    └── [FeatureName]Header.swift    # Optional components
```

### Adding a New Service
```
Services/
└── [ServiceName]Manager.swift       # Service class
```

### Adding a New Model
```
Models/
└── [ModelName].swift                # Model struct/class
```

## Future Expansion

The structure is ready for:

### Phase 2: Widgets
```
Widgets/
├── CrewluvWidget.swift
├── Timeline/
└── Views/
```

### Phase 3: Shared Components
```
Components/
├── Buttons/
├── Cards/
└── Text/
```

### Phase 4: Resources
```
Resources/
├── Colors.swift          # Color palette
├── Fonts.swift           # Typography system
└── Assets.xcassets/      # Images and assets
```

### Phase 5: Networking (if needed)
```
Networking/
├── APIClient.swift
├── Endpoints/
└── Models/
```

## Best Practices

1. **Single Responsibility** - Each file has one clear purpose
2. **Feature Cohesion** - Related files are grouped together
3. **Shallow Hierarchies** - Maximum 2-3 levels deep
4. **Descriptive Names** - File names clearly indicate contents
5. **Scalability** - Easy to add new features without refactoring

## Current Files

### App Layer (1 file)
- `CrewluvApp.swift` - App entry point with CloudKit share URL handling

### View Layer (2 files)
- `Views/Welcome/ContentView.swift` - Main coordinator view
- `Views/Status/PilotStatusView.swift` - Status display view

### Model Layer (1 file)
- `Models/SharedPilotStatus.swift` - Pilot status data model

### Service Layer (2 files)
- `Services/CloudKitShareManager.swift` - CloudKit operations
- `Services/PartnerStatusReceiver.swift` - Status fetching

### Utility Layer (1 file)
- `Utils/DebugLog.swift` - Debug logging

**Total: 7 Swift files, well-organized and ready to scale**

## Maintenance

- Keep this document updated when adding new directories
- Follow the established patterns when adding new files
- Group related functionality together
- Avoid creating deeply nested hierarchies
