# Trip Map: Fewer Markers Piled Up Near Home

Status: approved by Todd on 2026-11-14, after the "At base" preview showed Louisville's briefcase, the car parked on the drive from Lexington, and the two airport codes on top of each other. It covers the Crewluve app and the Crewluve website, which keep matching. It amends the moving map spec (`docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`) §7.1 and §10.

## 1. The car only while driving

Today every drive shows a car parked halfway along it at all times. Since the activity markers, every marker but the airports says what the pilot is doing now, and a parked car says nothing.

- **The car** shows only while the pilot is driving, where they are along the drive, as today.
- **A drive that's over, or still to come,** is its dotted line alone.

## 2. Crowded airports take turns

At the zoom a trip needs, airports a short drive apart sit on top of each other: Lexington's and Louisville's dots and codes for a commuter.

- **An airport only drives reach,** one no flight of the trip leaves from or lands at, gives way where it crowds another airport. MapKit hides it, as Apple Maps hides crowded labels, and shows it again as the map zooms in.
- **Every airport a flight uses** always shows, as today.
- **The plane, the pilot's marker and the car** always show, and never push an airport aside.
- In the app, airports take part in MapKit's collision detection (`collisionMode` `.rectangle`), with drive-only airports at a lower `displayPriority`. The other markers don't take part (`.none`).

## 3. Testing

- **`TripMapDrawingTests`:** no car before or after a drive, and the car halfway along it halfway through. A commuter's drive-only airport is named.
- **`TripMapMarkerTests`:** the car is named by its drive while driving, and an airport's marker says whether only drives reach it.
- **Todd's look:** the "At base" preview has no parked car, and only one of SDF and LEX shows when they'd overlap.

## 4. Amendments

- **Moving map spec §7.1:** "Drives are a dotted line with a small car" becomes a dotted line, with the car on it while the pilot drives.
- **Moving map spec §10, Markers:** where airport codes crowd each other, an airport only drives reach gives way.
