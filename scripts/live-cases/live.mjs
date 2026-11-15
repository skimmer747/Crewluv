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
export const FRESH = 120
export const AIRPORT_RADIUS = 10 * NM
export const ON_SCHEDULE_MINUTES = 5
export const UNSEEN_GAP = 10 * 60
export const FIRST_POINT_RADIUS = 30 * NM
export const WINDOW_OPENS_BEFORE = 30 * 60
export const WINDOW_CLOSES_AFTER = 2 * 3600
export const WINDOW_KEEPS_FOR = 30 * 60
export const WINDOW_ENDS_AFTER = 12 * 3600

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
  const trail = wire.trail.map((p) => ({ time: p[0] / 1000, at: [p[1], p[2]] }))
  // Oldest first, keeping the door's order between points of one time.
  const sorted = trail.map((p, i) => [p, i]).sort((a, b) => a[0].time - b[0].time || a[1] - b[1]).map((e) => e[0])
  return { state: wire.state, fix, landedAt: wire.landed_at === null ? null : wire.landed_at / 1000, trail: sorted }
}

// MARK: The path (spec §6.1)

export function makePath(origin, destination, flight) {
  const seen = flight ? flight.trail.map((p) => ({ at: p.at, time: p.time })) : []
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
  knots.push({ time: seen[0].time, along })
  for (let i = 1; i < seen.length; i++) {
    add(seen[i - 1].at, seen[i].at, seen[i].time - seen[i - 1].time > UNSEEN_GAP ? 'unseen' : 'seen')
    knots.push({ time: seen[i].time, along })
  }
  const flownBeforeLanding = along
  const final = seen[seen.length - 1]
  const landed = flight.state === 'landed'
  if (landed) {
    const landedAt = Math.max(flight.landedAt ?? flight.fix?.seenAt ?? final.time, final.time)
    add(final.at, destination, landedAt - final.time > UNSEEN_GAP ? 'unseen' : 'seen')
    knots.push({ time: landedAt, along })
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

// MARK: The record (spec §7.2)

export function makeRecord(path, plan) {
  if (!path.isReal) return null
  const knots = path.knots
  const first = knots[0], last = knots[knots.length - 1]
  const touchdown = path.landed ? last.time : last.time + timeToFly(plan, path.length - last.along)
  // The takeoff, when the first point was seen close enough to the airport to tell (spec §7.1).
  const takeoff = first.along <= FIRST_POINT_RADIUS ? first.time : null
  return { path, plan, knots, touchdown, takeoff }
}

export function alongAt(record, time) {
  const { path, plan, knots } = record
  const first = knots[0], last = knots[knots.length - 1]
  if (time <= first.time) return Math.max(0, first.along - (first.time - time) * planSpeed(plan))
  if (time >= last.time) {
    if (path.landed) return path.length
    return Math.min(Math.max(path.length - distanceLeft(plan, record.touchdown - time), last.along), path.length)
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
  if (d >= last.along) return path.landed ? last.time : record.touchdown - timeToFly(plan, path.length - d)
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
      phase = distance(fix.at, path.origin) <= AIRPORT_RADIUS ? 'onGround' : 'elsewhere'
    }
  }
  let touchdown = null
  if (phase === 'inAir' || phase === 'estimated') touchdown = fix.seenAt + timeToFly(plan, distance(fix.at, path.destination))
  if (phase === 'onGround' && now >= plan.takeoff) touchdown = now + (plan.touchdown - plan.takeoff)
  // A landed flight's touchdown is its record's, where it has one, so the two can't disagree.
  if (phase === 'landed') touchdown = record ? record.touchdown : (flight.landedAt ?? fix.seenAt)
  const liveArrival = touchdown === null ? null : touchdown + (plan.arrival - plan.touchdown)
  const gap = touchdown === null ? null : roundHalfAway((plan.touchdown - touchdown) / 60)

  let planeAlong = null, plane = null
  if (phase === 'inAir') { planeAlong = path.flown; plane = fix.at }
  if (phase === 'estimated') {
    planeAlong = Math.min(Math.max(path.length - distanceLeft(plan, touchdown - now), path.flown), path.length)
    plane = pointAt(path, planeAlong)
  }
  if (phase === 'landed') { planeAlong = path.length; plane = path.destination }
  if (phase === 'onGround') { planeAlong = 0; plane = fix.at }
  if (phase === 'elsewhere') plane = fix.at

  let ghostAlong = null
  if (phase === 'inAir' || phase === 'estimated' || phase === 'onGround') {
    if (now < plan.takeoff) ghostAlong = 0
    else ghostAlong = Math.max(0, path.length - distanceLeft(plan, plan.touchdown - now))
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
