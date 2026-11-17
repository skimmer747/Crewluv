# Crewluve Trip Map: Follow the Plane

Status: approved by Todd on 17 Nov 2026 ("Card and full screen", "Full-screen button, off", "Tail of 20% of the
flight", then "Yes, write it up"). The app's own camera: the website isn't part of it.

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

## 3. What it frames

While the setting is on and a flight is between its gates (`TripMap.legInMotion` is a flight):

- **The plane,** wherever the map draws it: the real plane where there's live data (as `FlightDrawing` places it), the
  schedule's otherwise, and the replay's plane at the replay's moment.
- **A tail behind it:** the stretch of the flight's path from 20% of the path's whole length behind the plane (or its
  start, if that's nearer) up to the plane. The tail is a steady size, so the plane is never hard against the edge.
- **Everything left,** along the path from the plane to the destination.
- **Room around it,** as the whole-flight framing has: the same margins, and the same clearances for the facts sheet,
  the panel and the card's chips (`TripMapClearance`).
- **Never narrower than about 300 miles** across, centred on the same middle, so near the end it's a regional view, not
  one airport filling the map.

Before the plane has left (the plan's takeoff, or a real plane still at the gate), the tail is nothing and the frame is
the whole flight, as today.

## 4. How it moves

- **In, in gentle steps:** the camera glides to the new frame only once the frame it wants is at least 15% smaller
  across than the one on screen, and no sooner than 5 seconds after its last move. A long flight live eases in now and
  then; a fast replay steps more often, never faster than that.
- **Out, at once:** whenever the plane or the destination would fall outside the frame on screen (dragging the replay
  back, a new leg, a real plane's path that bends away), it moves straight away, with the same glide.
- **The glide** is MapKit's own animated move, as every framing has today. With Reduce Motion on it moves without one.
- **The family's pan or pinch** stops it, as today, until they tap recenter, which frames as the setting says.
- **Turning the setting on or off** frames at once, the way the setting now says.

## 5. When it stands aside

On the ground, on a drive, before a trip and in the recap the map frames as it does today. A flight with no plane to
place frames the whole flight.

## 6. Tests

The frame and the step rule are plain logic beside `TripMapCamera`, `nonisolated` and tested:

- a flight's frame at its start, its middle and its last stretch, against expected rectangles, and the 300-mile floor;
- a frame before takeoff and with no plane, which are the whole flight's;
- the step rule: no move under 15% or within 5 seconds; a move at once when the plane or the destination would be out;
- the setting off, which frames as today.

Previews: the card and the full screen in flight with the setting on.

## 7. Left for later

- Following a drive.
- A frame that leads the plane by its heading on a flight that turns back on itself.
