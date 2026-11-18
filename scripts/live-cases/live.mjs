// The reference for live-cases.json: Stage 3's flight plan, path, record and progress (spec §4 to §7), written
// apart from the app's Swift and the website's TypeScript, so both are held to answers neither wrote.
// Distances are metres and times are seconds since 1970 unless a name says otherwise.

export const EARTH_RADIUS = 6371008.8
export const NM = 1852
export const TAXI_OUT = 15 * 60
export const TAXI_IN = 7 * 60
export const SHORTEST_CRUISE = 10 * 60
export const DESCENT_DISTANCE = 120 * NM
export const DESCENT_SPEED = 280 * NM / 3600
export const DESCENT_TIME = DESCENT_DISTANCE / DESCENT_SPEED
export const FRESH = 180
export const AIRPORT_RADIUS = 10 * NM
export const ON_SCHEDULE_MINUTES = 5
export const UNSEEN_GAP = 10 * 60
export const FIRST_POINT_RADIUS = 30 * NM
export const WINDOW_OPENS_BEFORE = 30 * 60
export const WINDOW_CLOSES_AFTER = 2 * 3600
export const WINDOW_KEEPS_FOR = 30 * 60
export const WINDOW_ENDS_AFTER = 12 * 3600
export const OWN_SPEED_LEAST = 10 * 60
export const OWN_SPEED_LEAST_SHARE = 0.7
export const OWN_SPEED_MOST_SHARE = 1.5
export const OWN_SPEED_AHEAD = 2 * 3600
export const RETURN_CLIMB_FEET = 1000
export const RESTART_GAP = 10 * 60

const rad = (d) => d * Math.PI / 180
const deg = (r) => r * 180 / Math.PI

// MARK: Great circles, as Utils/GreatCircle.swift. A place is [latitude, longitude].

function centralAngle(a, b) {
  const lat1 = rad(a[0]), lat2 = rad(b[0])
  const dLat = lat2 - lat1, dLon = rad(b[1] - a[1])
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2
  return 2 * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function distance(a, b) { return EARTH_RADIUS * centralAngle(a, b) }

export function pointBetween(a, b, fraction) {
  const share = Math.min(Math.max(fraction, 0), 1)
  const angle = centralAngle(a, b)
  if (!(angle > 1e-9)) return a
  const wa = Math.sin((1 - share) * angle) / Math.sin(angle)
  const wb = Math.sin(share * angle) / Math.sin(angle)
  const v = (p) => [Math.cos(rad(p[0])) * Math.cos(rad(p[1])), Math.cos(rad(p[0])) * Math.sin(rad(p[1])), Math.sin(rad(p[0]))]
  const va = v(a), vb = v(b)
  const x = wa * va[0] + wb * vb[0], y = wa * va[1] + wb * vb[1], z = wa * va[2] + wb * vb[2]
  return [deg(Math.atan2(z, Math.sqrt(x * x + y * y))), deg(Math.atan2(y, x))]
}

// MARK: The schedule's flight plan (spec §4)

export function makePlan(departure, arrival, length) {
  const block = arrival - departure
  if (!(block > 0)) return null
  const hasAllowances = block >= TAXI_OUT + TAXI_IN + SHORTEST_CRUISE
  const takeoff = hasAllowances ? departure + TAXI_OUT : departure
  const touchdown = hasAllowances ? arrival - TAXI_IN : arrival
  const inAir = touchdown - takeoff
  let cruise = null
  if (length > DESCENT_DISTANCE && inAir > DESCENT_TIME) {
    const speed = (length - DESCENT_DISTANCE) / (inAir - DESCENT_TIME)
    if (speed > DESCENT_SPEED) cruise = speed
  }
  // A short leg's one speed. A leg that goes nowhere has none of its own: the descent's stands in.
  const steady = cruise === null ? (length / inAir > 0 ? length / inAir : DESCENT_SPEED) : null
  return { departure, arrival, takeoff, touchdown, length, cruise, steady }
}

export const planSpeed = (plan) => plan.cruise ?? plan.steady

export function timeToFly(plan, far) {
  const d = Math.max(far, 0)
  if (plan.steady !== null) return d / plan.steady
  return d <= DESCENT_DISTANCE ? d / DESCENT_SPEED : DESCENT_TIME + (d - DESCENT_DISTANCE) / plan.cruise
}

export function distanceLeft(plan, time) {
  const t = Math.max(time, 0)
  if (plan.steady !== null) return t * plan.steady
  return t <= DESCENT_TIME ? t * DESCENT_SPEED : DESCENT_DISTANCE + (t - DESCENT_TIME) * plan.cruise
}

// MARK: A flight as partner_live answers it, read into seconds

export function readFlight(wire) {
  if (!wire) return null
  const fix = wire.fix && {
    at: [wire.fix.lat, wire.fix.lon], onGround: wire.fix.on_ground, seenAt: wire.fix.seen_at / 1000,
  }
  const trail = wire.trail.map((p) => ({ time: p[0] / 1000, at: [p[1], p[2]], feet: p[3] }))
  // Oldest first, keeping the door's order between points of one time.
  const sorted = trail.map((p, i) => [p, i]).sort((a, b) => a[0].time - b[0].time || a[1] - b[1]).map((e) => e[0])
  return { state: wire.state, fix, landedAt: wire.landed_at === null ? null : wire.landed_at / 1000, trail: sorted }
}

// MARK: An air return (air return design §2, §4)

/// Whether the highest of `points` is RETURN_CLIMB_FEET or more above the lowest. Points with no height don't count.
export function hasClimbed(points) {
  const feet = points.map((p) => p.feet).filter((f) => f !== null && f !== undefined)
  return feet.length > 0 && Math.max(...feet) - Math.min(...feet) >= RETURN_CLIMB_FEET
}

/// Whether the plane is back on the ground at its departure airport after flying: on the ground by Crewlu Cloud's
/// state, its last fix within 10 nm of the airport, and its whole trail climbed RETURN_CLIMB_FEET. How old the fix is
/// isn't asked: `progress` asks that.
export function isBack(flight, origin) {
  return flight?.state === 'ground' && !!flight.fix && distance(flight.fix.at, origin) <= AIRPORT_RADIUS
    && hasClimbed(flight.trail)
}

/// The trail points of the flight's latest try. A try starts again at a place seen in the air within FIRST_POINT_RADIUS
/// of the departure airport more than RESTART_GAP after the point before it, which was within 10 nm of it, once the try
/// before had climbed. The fix in the air, when it's newer than the trail, can start one too, with no points yet. While
/// the plane is back on the ground there, none.
export function latestTry(flight, origin) {
  if (!flight || isBack(flight, origin)) return []
  const trail = flight.trail
  const last = trail[trail.length - 1]
  const fix = flight.fix
  const places = fix && !fix.onGround && (!last || fix.seenAt > last.time) ? [...trail, { time: fix.seenAt, at: fix.at }] : trail
  let start = 0
  for (let i = 1; i < places.length; i++) {
    const earlier = places[i - 1], later = places[i]
    if (later.time - earlier.time > RESTART_GAP && distance(earlier.at, origin) <= AIRPORT_RADIUS
        && distance(later.at, origin) <= FIRST_POINT_RADIUS && hasClimbed(trail.slice(start, i))) start = i
  }
  return trail.slice(start)
}

// MARK: The path (spec §6.1)

export function makePath(origin, destination, flight) {
  // The latest try alone: an air return and the wait after it aren't the flight's path (air return design §4).
  const seen = latestTry(flight, origin).map((p) => ({ at: p.at, time: p.time }))
  const last = seen[seen.length - 1]
  if (flight?.fix && !flight.fix.onGround && (!last || flight.fix.seenAt > last.time)) {
    seen.push({ at: flight.fix.at, time: flight.fix.seenAt })
  }
  if (seen.length === 0) {
    const length = distance(origin, destination)
    return { origin, destination, isReal: false, length, flown: 0, knots: [],
             stretches: [{ from: origin, to: destination, kind: 'planned', start: 0, length }] }
  }
  const stretches = []
  const knots = []
  let along = 0
  const add = (from, to, kind) => {
    const length = distance(from, to)
    stretches.push({ from, to, kind, start: along, length })
    along += length
  }
  add(origin, seen[0].at, distance(origin, seen[0].at) > FIRST_POINT_RADIUS ? 'unseen' : 'seen')
  knots.push({ time: seen[0].time, along, at: seen[0].at })
  for (let i = 1; i < seen.length; i++) {
    add(seen[i - 1].at, seen[i].at, seen[i].time - seen[i - 1].time > UNSEEN_GAP ? 'unseen' : 'seen')
    knots.push({ time: seen[i].time, along, at: seen[i].at })
  }
  const flownBeforeLanding = along
  const final = seen[seen.length - 1]
  const landed = flight.state === 'landed'
  if (landed) {
    const landedAt = Math.max(flight.landedAt ?? flight.fix?.seenAt ?? final.time, final.time)
    add(final.at, destination, landedAt - final.time > UNSEEN_GAP ? 'unseen' : 'seen')
    knots.push({ time: landedAt, along, at: destination })
  } else {
    add(final.at, destination, 'planned')
  }
  return { origin, destination, isReal: true, length: along, flown: landed ? along : flownBeforeLanding, knots, stretches,
           landed, firstPointAlong: knots[0].along }
}

export function pointAt(path, far) {
  const d = Math.min(Math.max(far, 0), path.length)
  for (const s of path.stretches) {
    if (d <= s.start + s.length) {
      return s.length > 0 ? pointBetween(s.from, s.to, (d - s.start) / s.length) : s.from
    }
  }
  return path.destination
}

// MARK: The plan as the plane flies it (spec §4)

/// The plane's own speed over its cruise so far: the distance it flew along its path over the time it took, counted
/// over each stretch between two neighbouring places that were both seen in its cruise, when those stretches come to
/// ten minutes or more. A place is in the cruise when it's the descent's distance or more from both airports, in a
/// straight line. That never changes, so a hold or a pattern near the arrival airport can't bring its places into the
/// cruise, and neither can a return to the departure airport and the wait there.
export function ownSpeed(path) {
  if (!path.isReal) return null
  const isInCruise = (k) =>
    distance(path.origin, k.at) >= DESCENT_DISTANCE && distance(k.at, path.destination) >= DESCENT_DISTANCE
  let time = 0, length = 0
  for (let i = 1; i < path.knots.length; i++) {
    const earlier = path.knots[i - 1], later = path.knots[i]
    if (isInCruise(earlier) && isInCruise(later)) {
      time += later.time - earlier.time
      length += later.along - earlier.along
    }
  }
  return time >= OWN_SPEED_LEAST ? length / time : null
}

/// The schedule's plan with the plane's own speed for its cruise, once that's known and could be right: from 0.7 of
/// the plan's cruise speed to 1.5 of it. The cruise left from the last place the plane was seen is flown at its own
/// speed for two hours, or all the way when that's further, and at the plan's after that: the plan's cruise is the one
/// speed that flies it all in the same time (long gap design §2). Its takeoff and touchdown are still the schedule's.
export function flownPlan(plan, path) {
  if (plan.cruise === null) return plan
  const own = ownSpeed(path)
  if (own === null || !(own >= plan.cruise * OWN_SPEED_LEAST_SHARE && own <= plan.cruise * OWN_SPEED_MOST_SHARE)) return plan
  const cruiseLeft = path.length - path.flown - DESCENT_DISTANCE
  if (!(cruiseLeft > 0)) return { ...plan, cruise: own }
  const atOwn = Math.min(cruiseLeft, own * OWN_SPEED_AHEAD)
  return { ...plan, cruise: cruiseLeft / (atOwn / own + (cruiseLeft - atOwn) / plan.cruise) }
}

// MARK: The record (spec §7.2)

export function makeRecord(path, plan) {
  if (!path.isReal) return null
  const knots = path.knots
  const first = knots[0], last = knots[knots.length - 1]
  const flown = flownPlan(plan, path)
  const touchdown = path.landed ? last.time : last.time + timeToFly(flown, path.length - last.along)
  // The takeoff, when the first point was seen close enough to the airport to tell (spec §7.1).
  const takeoff = first.along <= FIRST_POINT_RADIUS ? first.time : null
  return { path, plan, flown, knots, touchdown, takeoff }
}

export function alongAt(record, time) {
  const { path, plan, knots } = record
  const first = knots[0], last = knots[knots.length - 1]
  if (time <= first.time) return Math.max(0, first.along - (first.time - time) * planSpeed(plan))
  if (time >= last.time) {
    if (path.landed) return path.length
    return Math.min(Math.max(path.length - distanceLeft(record.flown, record.touchdown - time), last.along), path.length)
  }
  for (let i = 1; i < knots.length; i++) {
    if (time < knots[i].time) {
      const a = knots[i - 1], b = knots[i]
      return a.along + (b.along - a.along) * (time - a.time) / (b.time - a.time)
    }
  }
  return last.along
}

export function timeAt(record, far) {
  const { path, plan, knots } = record
  const d = Math.min(Math.max(far, 0), path.length)
  const first = knots[0], last = knots[knots.length - 1]
  if (d <= first.along) return first.time - (first.along - d) / planSpeed(plan)
  if (d >= last.along) return path.landed ? last.time : record.touchdown - timeToFly(record.flown, path.length - d)
  for (let i = 1; i < knots.length; i++) {
    if (d <= knots[i].along) {
      const a = knots[i - 1], b = knots[i]
      return b.along > a.along ? a.time + (b.time - a.time) * (d - a.along) / (b.along - a.along) : a.time
    }
  }
  return last.time
}

// MARK: Progress (spec §5)

export function roundHalfAway(x) { return Math.sign(x) * Math.floor(Math.abs(x) + 0.5) || 0 }

export function minutesText(minutes) {
  const hours = Math.floor(minutes / 60), rest = minutes % 60
  if (hours === 0) return `${rest} min`
  if (rest === 0) return `${hours} h`
  return `${hours} h ${rest} min`
}

export function labelFor(phase, gap) {
  // Back at the departure airport, whatever the gap: the words name the airport (air return design §3).
  if (phase === 'returned') return 'Returned'
  if (gap === null) return null
  const size = Math.abs(gap)
  const onSchedule = size <= ON_SCHEDULE_MINUTES
  switch (phase) {
    case 'inAir': return onSchedule ? 'On schedule' : `${minutesText(size)} ${gap > 0 ? 'ahead' : 'behind'}`
    case 'estimated': return onSchedule ? 'On schedule' : `About ${minutesText(size)} ${gap > 0 ? 'ahead' : 'behind'}`
    case 'onGround': return onSchedule ? 'Still on the ground' : `Still on the ground · ${minutesText(size)} behind`
    case 'landed': return onSchedule ? 'Landed on time' : `Landed ${minutesText(size)} ${gap > 0 ? 'early' : 'late'}`
    default: return null
  }
}

export function progress(plan, path, record, flight, now) {
  let phase = 'notLive'
  const fix = flight?.fix
  if (fix) {
    const isFresh = now - fix.seenAt <= FRESH
    if (flight.state === 'landed') phase = 'landed'
    else if (flight.state === 'airborne') phase = isFresh ? 'inAir' : 'estimated'
    else if (flight.state === 'ground' && isFresh) {
      if (distance(fix.at, path.origin) > AIRPORT_RADIUS) phase = 'elsewhere'
      else phase = isBack(flight, path.origin) ? 'returned' : 'onGround'
    }
  }
  // The plane's own speed stands in for the plan's cruise, for the estimate, the estimated plane and the ghost alike.
  const flown = flownPlan(plan, path)
  let touchdown = null
  if (phase === 'inAir' || phase === 'estimated') touchdown = fix.seenAt + timeToFly(flown, distance(fix.at, path.destination))
  // Past the plan's takeoff, a plane at the departure airport, still or again, takes off this moment.
  if ((phase === 'onGround' || phase === 'returned') && now >= plan.takeoff) touchdown = now + (plan.touchdown - plan.takeoff)
  // A landed flight's touchdown is its record's, where it has one, so the two can't disagree.
  if (phase === 'landed') touchdown = record ? record.touchdown : (flight.landedAt ?? fix.seenAt)
  const liveArrival = touchdown === null ? null : touchdown + (plan.arrival - plan.touchdown)
  const gap = touchdown === null ? null : roundHalfAway((plan.touchdown - touchdown) / 60)

  let planeAlong = null, plane = null
  if (phase === 'inAir') { planeAlong = path.flown; plane = fix.at }
  if (phase === 'estimated') {
    planeAlong = Math.min(Math.max(path.length - distanceLeft(flown, touchdown - now), path.flown), path.length)
    plane = pointAt(path, planeAlong)
  }
  if (phase === 'landed') { planeAlong = path.length; plane = path.destination }
  if (phase === 'onGround' || phase === 'returned') { planeAlong = 0; plane = fix.at }
  if (phase === 'elsewhere') plane = fix.at

  let ghostAlong = null
  if (phase === 'inAir' || phase === 'estimated' || phase === 'onGround') {
    if (now < plan.takeoff) ghostAlong = 0
    else ghostAlong = Math.max(0, path.length - distanceLeft(flown, plan.touchdown - now))
  }

  // The leg's real times (spec §7.1).
  const takeoff = record?.takeoff ?? null
  const earlyStart = takeoff === null ? null : takeoff - (plan.takeoff - plan.departure)
  const start = earlyStart !== null && earlyStart < plan.departure ? earlyStart : plan.departure
  const end = liveArrival ?? plan.arrival

  return { phase, touchdown, liveArrival, gap, label: labelFor(phase, gap), planeAlong, plane, ghostAlong,
           ghost: ghostAlong === null ? null : pointAt(path, ghostAlong), start, end }
}

// MARK: The window (spec §10.2, partner-api.md)

export function isWindowOpen(departure, arrival, flight, now) {
  if (now < departure - WINDOW_OPENS_BEFORE) return false
  if (flight?.state === 'landed') return false
  if (now < arrival + WINDOW_CLOSES_AFTER) return true
  return flight?.state === 'airborne' && !!flight.fix && flight.fix.seenAt > now - WINDOW_KEEPS_FOR
    && now < arrival + WINDOW_ENDS_AFTER
}
