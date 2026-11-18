# Crewluve Trip Map: Follow the Plane

Status: approved by Todd on 17 Nov 2026 ("Card and full screen", "Full-screen button, off", "Tail of 20% of the
flight", then "Yes, write it up"). The app's own camera: the website isn't part of it.

Revised the same day after Todd tried it ("It doesn't zoom in close enough and it zooms and stops and zooms and stops on
playback", "It still has way more behind the plane than in front. The destination needs to stay in view"): the first
build's step rule moved only when the frame shrank by 15%, so as the frame slid forward at about the same size the
camera kept its old middle, and its steps came 5 seconds apart. Now the tail is 10% ("10% of the flight") and the map
glides continuously toward the frame ("Yes, write it up"): §3 and §4.

## 1. Why

In flight the map frames the whole flight when the leg begins (`TripMap.framingRect(focusingOn:)`) and keeps that view
until the next leg. Live or in a replay, the plane crawls across a map that never comes closer, and at the end of a
long flight the arrival is a small corner of it. Todd likes today's view too, so following is a choice.

## 2. The setting

- **"Follow the plane",** one setting for the card and the full-screen map, remembered (`@AppStorage`
  `tripMapFollowsPlane`), as Quick layovers is.
- **Off at first,** so today's whole-flight view stays until the family turns it on.
- **Switched on the full-screen map** by a button beside recenter: `airplane.circle`, filled while it's on,
  and to VoiceOver "Follow the plane", with the value "on" or "off". The card has no button: it follows the setting.
- **What the button says** (after Todd's look: "You tap it and it doesn't look any different. You don't know if its on
  or off or what it does", then "Tint plus a caption"): while on it's tinted, in the accent colour (iOS 26's prominent
  glass), and plain glass when off. Each tap shows a short caption under the top bar for about two seconds, "Following
  the plane" or "Showing the whole flight", or with no flight in the air "Follows the plane when a flight is in the
  air", which VoiceOver announces. Its VoiceOver hint: "Keeps the map on the plane and where it's headed."

## 3. What it frames

While the setting is on and a flight is between its gates (`TripMap.legInMotion` is a flight):

- **The plane,** wherever the map draws it: the real plane where there's live data (as `FlightDrawing` places it), the
  schedule's otherwise, and the replay's plane at the replay's moment.
- **A tail behind it:** the stretch of the flight's path from 10% of the path's whole length behind the plane (or its
  start, if that's nearer) up to the plane. The tail is a steady size, so the plane is never hard against the edge.
- **Everything left,** along the path from the plane to the destination, which always stays in view.
- **Room around it,** as the whole-flight framing has: the same margins, and the same clearances for the facts sheet,
  the panel and the card's chips (`TripMapClearance`).
- **Never narrower than about 300 miles** across, centred on the same middle, so near the end it's a regional view, not
  one airport filling the map.

Before the plane has left (the plan's takeoff, or a real plane still at the gate), the tail is nothing and the frame is
the whole flight, as today.

## 4. How it moves

- **A continuous glide:** SwiftUI hands the map the frame it wants on every tick (up to 60 a second in a replay, once a
  second live, every 10 seconds on the card), and the map itself eases toward it on every display frame, its middle
  and its zoom together, catching up in about a second. Nothing steps, so nothing stops and starts. Live, the frame
  changes so slowly the motion is hardly seen; a replay is tracked smoothly; a replay dragged back glides to its new
  frame.
- **No SwiftUI state on each frame:** the frame wanted is a plain value the map is drawn with, not the camera's state,
  so the glide redraws only the map, not the screen.
- **New margins glide too.** The frame keeps clear of the latest event's banner, which comes at a takeoff and goes a few
  minutes on, so the map's margins change then; laid out in them at once the map jumped ("it still does a skip thing
  everytime the legs starts", found by a log of the camera). While following, new margins ease in by the glide's own
  share. A glide starts from the frame the map was last asked to show, not an estimate of what it shows, which was
  about 88 points off.
- **With Reduce Motion on** it follows without the glide.
- **The family's pan or pinch** stops it, as today, until they tap recenter, which frames as the setting says.
- **Turning the setting on or off** frames at once, the way the setting now says.

## 5. Between legs, and when it stands aside

While the setting is on, the glide makes every move of the camera, between legs too, so no two animations ever compete
(after Todd's look: "every time the app starts a new leg. It zooms in and zooms out like its trying to do more things
than one", then "The next flight"). The first build framed a new leg with MapKit's animation, framed it twice when a
flight ended (once for the leg, once for following stopping), zoomed out to the whole trip for each short wait, and
slid the pilot's marker into view on top.

- **A flight that hasn't left** frames the whole flight, as before.
- **On the ground between two flights** it frames the next flight's whole route, which starts where the pilot is: after
  landing the map eases out to it, and after takeoff in again.
- **Otherwise,** before the trip's first flight, after its last, and on a drive, it frames what the map frames without
  the setting: the leg in motion, or the whole trip.
- **With the setting off,** the map frames as it did before Follow the plane.

## 6. Tests

The frame and the glide's step are plain logic beside `TripMapCamera`, `nonisolated` and tested:

- a flight's frame at its start, its middle and its last stretch, against expected rectangles, and the 300-mile floor;
- a frame before takeoff and with no plane, which are the whole flight's;
- the glide's step: part of the way toward the frame each display frame, more the longer the frame, the middle and the
  zoom eased together, across the date line the short way, and arriving without overshoot;
- the setting off, which frames as today.

Previews: the card and the full screen in flight with the setting on.

## 7. Left for later

- Following a drive.
- A frame that leads the plane by its heading on a flight that turns back on itself.
