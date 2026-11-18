# Crewluve Trip Map: An Air Return

Status: approved by Todd on 17 Nov 2026, from the website session's request ("Send it to the app's session"). The app
leads: the rule goes in the shared engine (`scripts/live-cases/live.mjs`, the app's `LiveProgress`, `FlightPath` and
`FlightRecord`) with new cases in `live-cases.json`, and the website follows with its own plan.

## 1. Why

A plane that takes off and lands back at its departure airport is, to Crewlu Cloud, `ground` again within 10 nm of that
airport. The engine calls that `onGround`, so a family reads "Still on the ground · …" on the bar and "Still on the ground
in Rockford" in the facts: the same words as a plane that never left the gate. The plane did leave, and the family deserves
to know it came back.

Once it takes off again, the trail still holds the first trip out and back. The path, the record and the estimate are
made from the whole trail, so they think the plane is further along than it is.

## 2. When a plane has returned

All three, at `now`:

- **Crewlu Cloud says `ground`,** with a fresh fix (as `onGround` needs today),
- **within 10 nm of the departure airport** (`LiveProgress.airportRadius`, as `onGround`), and
- **its trail has climbed 1,000 ft:** the highest trail point is at least 1,000 ft above the lowest
  (`LiveFlight.returnClimbFeet`, `RETURN_CLIMB_FEET`). Points with no height don't count.

Otherwise it's `onGround`, as today. The trail only holds points in the air (Stage 3 spec §10.5), so a plane that never
left has none. Heights are from sea level and Crewluve knows no airport's elevation, so the rule is a climb, not a height:
a plane taxiing at Denver reads 5,400 ft, and a single stray point in the air can't climb at all.

This is a new phase, `returned`, beside `onGround`, `elsewhere` and the rest.

## 3. While it's back on the ground

- **The real plane** is drawn where its fix is, at the departure airport, at the start of its path, as `onGround` draws
  it. **No ghost.**
- **The landing estimate** is as `onGround`'s: past the plan's takeoff, "now plus the plan's time in the air". So the leg
  stays open: the cards don't say the pilot reached the arrival airport at the scheduled time while the plane sits at the
  departure one.
- **The words** (Rockford is the departure airport's city):

| Where | Today | Returned |
|---|---|---|
| The card's bar, its label | "Still on the ground · 40 min behind" | **Returned to Rockford** |
| The facts' headline, first row and the card's chip | "Still on the ground in Rockford" | **Returned to Rockford** |
| The line under the timeline (and the slider's spoken value) | "Mon 12:21 PM · On the ground in Rockford" | **Mon 12:21 PM · Returned to Rockford** |
| The status page's sentence | "Alex is still on the ground in Rockford on UPS flight 2963 to Anchorage — landing in …" | **Alex has returned to Rockford on UPS flight 2963 to Anchorage — landing in … which is about …** (with no flight number, "on the flight") |
| The plane's popup | "Still on the ground · 40 min behind", "Lands about 9:11 AM" | **Returned to Rockford**, "Lands about 9:11 AM" |
| VoiceOver's label | "still on the ground" | **returned to Rockford** |

The facts' other rows are as "Still on the ground" has them: nothing of what's below, no sky row, and the plane's row
with no height or speed.

- **Now only,** as "Still on the ground" is: a replay reads the map's plane, as before.

## 4. A second takeoff starts the path afresh

The trail **restarts** at a point that:

- is within 30 nm of the departure airport (`FlightPath.firstPointRadius`, as for a first point that tells the
  takeoff), since coverage low down can miss the first minutes of the climb,
- comes more than 10 minutes after the point before it (`LiveFlight.restartGap`, `RESTART_GAP`), and
- comes after the trail had climbed 1,000 ft (§2), with the point before it within 10 nm.

The plane's fix in the air, when it's newer than the trail, can start one too, so the path is right from the takeoff,
before its first new point (from the plan's review).

Only the points from the last restart on make the path, the record (its takeoff, touchdown and what it saw) and the
plane's own speed. The first trip out and back isn't drawn. Points arrive every 110 s in the air, so a plane holding near
the airport never leaves a 10-minute gap, and a plane back on the ground leaves no points at all until it flies again.

The climb in §2 is read from the whole trail, so a plane back on the ground after a second try is "Returned" again,
and one that has just taken off again is in the air as any other.

## 5. Tests

- **Shared cases** (`generate.mjs`, never the JSON by hand), each with moments:
  - "air return, back on the ground": out to 40 nm, climbing to 9,000 ft, and back; `returned`, the plane at the airport,
    no ghost, the estimate "now plus the time in the air", the label "Returned".
  - "air return, then off again": the same, then a new climb an hour later; `inAir`, its path, flown distance and ghost
    from the second takeoff only.
  - "a stray point while taxiing": one trail point at the airport's height, then `ground`; still `onGround`.
- **App tests** for the words in each place in §3, and that a replay reads as before.

## 6. Left for later

- A return to an airport other than the departure one stays a diversion (`elsewhere`), as today.
- A flight cancelled after a return reads "Returned to Rockford" until Crewlu Cloud stops watching it.
- The first trip out and back drawn as a faint line.
