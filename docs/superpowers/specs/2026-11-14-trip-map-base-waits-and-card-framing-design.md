# Trip Map: Waits at Base, and a Card That Keeps the Pilot in View

Status: approved in brainstorming with Todd on 2026-11-14, right after the activity markers shipped (`docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`). It covers the Crewluve app and the Crewluve website, which keep matching. It amends the activity markers design §2.2 and the moving map spec (`docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`) §5.1 and §10.

## 1. Goal

Three things turned up once the pilot's marker said what they were doing:

- **A commuter's wait at base is named "Turn" or "Layover".** CrewLu sends the drives between home and base, the flights, and a ground leg between flights and between duty days. It sends nothing for the wait between the drive to base and the first flight, or between the last landing and the drive home. With no ground leg, the activity rule names a wait by its length: under 8 hours a turn, 8 hours or more a layover. The shared commuter case missed this because it gives those waits `base` legs CrewLu never sends. The website names the first of them "base" through its own report leg.
- **A pilot waiting at base for a trip is shown at home.** The status says "At base", but the card shows the next trip with the house at home and "Home · next trip Friday". The heart had the same place; the house makes it plainly wrong.
- **The card can lose the pilot's marker.** On a wide trip, such as Louisville to Cologne and Dubai, MapKit won't zoom out far enough, and Louisville falls off the card's left edge with the marker on it. On a layover, the "Next: …" chip can cover the marker. The website has both problems too.

## 2. A wait CrewLu doesn't name

A wait still takes its name from the CrewLu ground leg that overlaps it most (activity markers design §2.2). With none, it's named by where it is, then by its length:

1. At the pilot's **home** airport: **home**.
2. At the pilot's **base** airport: **base**, "At base in Louisville".
3. Anywhere else: 8 hours or more is a **layover**, less is a **turn**, as today.

- **Where a wait is:** the destination of the leg the wait follows, the one that ended last before it, as the marker already places the pilot.
- **Home** is the summary's home airport, or its base when it has no home, as the map already takes it. **Base** is the summary's base airport. With no base, rule 2 never applies, so a CrewLu that doesn't send its base reads as today.
- **Home before base:** for a pilot whose home and base are the same airport, a wait there is home, as their status reads it.
- **Who this reaches:** only waits CrewLu leaves unnamed. CrewLu names every turn and every night away, so in practice these are a commuter's waits at base and, on the website, waits its own legs don't cover.

## 3. Waiting at base for the next trip

The map shows a trip ahead when the pilot is at home or at base (`TripMap.Mode.nextTrip`). When the summary's status is **base** (`displayStatus == .base`):

- **The marker** is the briefcase at base, not the house at home. Base is placed as the trip's own legs name it, so it has its city: "At base in Louisville". If no leg names it, the marker goes on the trip's first departure airport.
- **The chip** reads "At base · next trip Friday", and so does the full-screen panel's first line.
- **Everything else** is as today: the route, every leg dashed, and home still in the framing.

When the status says **home**, nothing changes: the house at home, "Home · next trip Friday".

## 4. A card that keeps the pilot in view

### 4.1 The band between the chips

The card frames its map in the band between its two chips, so nothing sits under them.

- **How:** the card measures its chips' heights and passes them to the map as clearance, top and bottom: from the map's edge to the chip's far edge, its 10-point padding included, plus a 4-point gap, as the website measures them. As with the facts sheet and panel (Stage 2 spec §6.1, §6.2), the clearance goes into the map's layout margins. MapKit fits the trip inside them and keeps Apple's logo and Legal link in them, so the logo moves above the bottom chip.
- **Only heights:** a chip's words change every few seconds ("9:14 PM there"), but its height changes only with the text size. So the camera never moves because a chip's words did.
- **No chip, no band:** the band follows the chips shown. At the largest text sizes the chips move below the map (moving map spec §14), and the map takes its whole height.
- The full-screen map keeps its sheet and panel clearance as today.

### 4.2 Sliding to the marker

The band leaves the card less room, so a wide trip is more likely to be cut off. So once the map has framed, it checks the pilot's marker:

- **When:** on each framing, of the card or the full-screen map: as the map opens, as the trip changes, as its size or margins change, on recenter, and as a flight starts or ends, which the full-screen map already frames for, in a replay too. Never otherwise, so the map never follows the marker from moment to moment, and once the family has moved it, it stays where they put it.
- **Which marker:** the ground marker (the bed, hourglass, briefcase or house), where the pilot is at the moment the map shows when it frames: now on the card, and the timeline's moment on the full-screen map. In flight the camera frames the flight as today.
- **The check:** the marker's frame, plus 8 points all round, must lie inside the map's layout margins: inside the band on the card, clear of the sheet or panel on the full-screen map.
- **The slide:** when it doesn't, the map slides the shortest distance that brings it inside, along each axis on its own. It never zooms, so the rest of the trip loses as little as it can. A marker larger than the space is centered in it.
- **Animation:** a framing without animation, as on the card, slides at once, before anything is drawn. A framing with animation, as recenter on the full-screen map, slides with an animation once it has finished. If the family touches the map before then, the slide is dropped.

## 5. The website

The website keeps matching. Its session builds the same rules in its own code:

- the wait rule (§2), with its report leg still a ground leg that names its wait;
- waiting at base for the next trip (§3);
- the card's band and the slide (§4).

`activity-cases.json` holds both to §2 and §3 (§7). The website's map has its own camera, so §4 has no shared cases.

## 6. The app's parts

- **`TripMap`** gains `base`, an `AirportMark` the trip's legs name where they can, and `isWaitingAtBase`, true only for a trip ahead with the status at base. `make` takes the summary's base code and whether the pilot is waiting at base; `TripMap(status:at:)` passes `baseAirportCode` and `displayStatus == .base`.
- **`TripMap+Activity`:** a wait with no ground stop is named by where it is (§2). Before the trip, a pilot waiting at base is at base (§3).
- **`TripMap.pilotLocation(at:)`:** before a trip ahead, base when waiting at base, else home (§3).
- **`TripMapWording`:** `nextTripChip` says "At base" when waiting at base, for the card's chip and the panel's first line.
- **`TripMapClearance`** gains `top`. The card ignores the safe area, so its clearance goes into the margins as measured.
- **`TripMapCard`** measures its chips' heights and passes `TripMapClearance(top:bottom:)` to its `TripMapView`.
- **`TripMapCamera`** carries the coordinate to keep in view with each framing: the pilot's ground marker at that moment, or none in flight.
- **`TripMapCameraController`** checks and slides after each framing (§4.2). The coordinator tells it when an animated framing has finished.
- **The slide's maths** is a `nonisolated` function of rectangles alone, apart from MapKit, and tested on its own.

## 7. Testing

- **`activity-cases.json`**, in both copies:
  - trips gain an optional `base`, and a trip ahead gains an optional `waitingAt`, `"base"` or `"home"` (the default);
  - a new trip: a commuter whose CrewLu sends no `base` legs, with moments after the drive to base and before the drive home, both "At base in Louisville", and a wait elsewhere with no ground leg still named by its length;
  - a new trip: a next trip while waiting at base, with the briefcase at base until it starts;
  - the cases already there are unchanged, and still pass.
- **App unit tests:** the wait rule, home before base; `pilotLocation` and the activity before a trip ahead, at home and at base; the chip's words; the slide: a marker already inside doesn't move, off each edge it slides back just inside, and one larger than the space is centered; the clearance's top edge in the margins.
- **Todd's device check:**
  - **Louisville to Cologne and Dubai on the card:** at base before the trip, during the trip, and in the recap, the marker always shows, and no chip covers it or a route's airport.
  - **A commuter's trip:** the replay reads "At base in Louisville" between the drive to base and the first flight, and between the last landing and the drive home.
  - **Waiting at base before the trip:** the briefcase at base, and "At base · next trip …".
  - **Apple's logo** on the card sits above the bottom chip.
  - **The full-screen map:** recenter slides the marker into view after its zoom when a trip is too wide, and a replay never moves the map by itself.

## 8. Not in this design

- **A plane under a chip in flight.** The camera frames the flight, and the plane moves on.
- **Keeping the marker in view during a replay.** The map would wander as the marker moves from city to city.
- **The cities line on a commuter's next trip,** which lists base among the trip's cities.

## 9. Amendments

- **Activity markers design §2.2:** a wait with no ground leg is named by where it is, then by its length (§2 here). Before a trip ahead, a pilot waiting at base is at base (§3).
- **Moving map spec §5.1:** "Home, with a trip ahead" gains "At base, with a trip ahead" (§3). The card frames the trip between its chips and keeps the pilot's marker in view (§4).
- **Moving map spec §10:** the camera slides to the pilot's marker after framing when it falls outside the margins (§4.2), and the card's chips join the sheet and panel in the margins (§4.1).
