# CrewLuv

**Stay connected with your pilot.** CrewLuv is a 100% free companion app for pilots' partners and family members.

## Features

- **Real-time Status** - See if your pilot is home, in flight, or on layover
- **Countdown Timer** - Know exactly when they'll be home
- **Location Tracking** - View current city, airport, and local time
- **Trip Progress** - See what day of their trip they're on
- **Flight Information** - Track current and upcoming flights
- **Auto-refresh** - Status updates every 2 minutes

## Requirements

- iOS 17.0+
- iCloud account
- Pilot must have the [Duty app](https://github.com/toddaa/Duty) with Duty Plus subscription

## How It Works

1. **Pilot Setup**: Your pilot needs the Duty app with an active Duty Plus subscription
2. **Share Invitation**: They invite you via Settings → Partner Sharing → Invite Partner
3. **Accept & Connect**: Accept the CloudKit share link (via iMessage or manual paste)
4. **Stay Connected**: CrewLuv automatically syncs their status every 2 minutes

## Privacy

CrewLuv only shares essential information:
- Current location (city/airport)
- Flight status (in flight, on duty, at home)
- Arrival/departure times
- Trip progress

**Not shared**: Crew names, hotel details, pay information, or other sensitive data.

## Architecture

CrewLuv uses CloudKit sharing to receive read-only status updates from the Duty app:

- **Separate CloudKit Zone**: Uses `PartnerBeaconZone` (isolated from Duty's SwiftData sync)
- **One-way Sync**: Duty app generates status snapshots, CrewLuv receives them
- **Lightweight Model**: `SharedPilotStatus` struct optimized for CloudKit sharing

## Installation

1. Clone this repository
2. Open `Crewluv.xcodeproj` in Xcode
3. Update the bundle identifier and team settings
4. Build and run on your device

## License

MIT License - See LICENSE file for details

## Related Projects

- [Duty](https://github.com/toddaa/Duty) - The pilot scheduling app that powers CrewLuv

---

Made with ❤️ for aviation families
