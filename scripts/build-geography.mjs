// Writes Crewluv/Resources/TripMap/geography.json (moving map Stage 2 spec §9.1): US states, Canadian provinces,
// countries, named seas and oceans, and cities of a million or more, from Natural Earth (public domain).
// Reads scripts/natural-earth/*.geojson (downloaded, not committed). Run: node scripts/build-geography.mjs
import { existsSync, readFileSync, writeFileSync } from 'node:fs'

const sources = ['ne_50m_admin_0_countries', 'ne_50m_admin_1_states_provinces', 'ne_50m_geography_marine_polys', 'ne_10m_populated_places_simple']
const missing = sources.filter(name => !existsSync(new URL(`./natural-earth/${name}.geojson`, import.meta.url)))
if (missing.length > 0) {
  console.error(`Missing Natural Earth files in scripts/natural-earth/: ${missing.map(name => `${name}.geojson`).join(', ')}.\n` +
    `The build needs ${sources.map(name => `${name}.geojson`).join(', ')}.\n` +
    'Each comes from https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/<name>.geojson')
  process.exit(1)
}

const read = name => JSON.parse(readFileSync(new URL(`./natural-earth/${name}.geojson`, import.meta.url), 'utf8'))
const target = new URL('../Crewluv/Resources/TripMap/geography.json', import.meta.url)
const largestFile = 500_000

// Natural Earth's field names are upper case in some files and lower case in others.
const field = (feature, key) => feature.properties[key] ?? feature.properties[key.toUpperCase()] ?? feature.properties[key.toLowerCase()]

// Countries whose names read with "the": "Over the Netherlands".
const withThe = new Set([
  'United States', 'United Kingdom', 'Netherlands', 'Philippines', 'Bahamas', 'Gambia', 'Maldives', 'Marshall Islands',
  'Solomon Islands', 'Comoros', 'Seychelles', 'Czech Republic', 'Dominican Republic', 'Central African Republic',
  'Democratic Republic of the Congo', 'Republic of the Congo', 'United Arab Emirates', 'Faroe Islands', 'Falkland Islands',
  'Cayman Islands', 'Cook Islands', 'Turks and Caicos Islands', 'British Virgin Islands', 'United States Virgin Islands',
  'Northern Mariana Islands', 'Vatican City',
])
const renamed = {
  'United States of America': 'United States',
  "People's Republic of China": 'China',
  'Federated States of Micronesia': 'Micronesia',
}
// Keyed lower case: the lookup ignores case.
const oceans = {
  'atlantic ocean': 'the Atlantic', 'north atlantic ocean': 'the Atlantic', 'south atlantic ocean': 'the Atlantic',
  'pacific ocean': 'the Pacific', 'north pacific ocean': 'the Pacific', 'south pacific ocean': 'the Pacific',
  'indian ocean': 'the Indian Ocean', 'arctic ocean': 'the Arctic Ocean', 'southern ocean': 'the Southern Ocean',
}
const waterOverrides = { 'tikahtnu inlet': 'Cook Inlet' }
const waterClasses = new Set(['ocean', 'sea', 'bay', 'gulf', 'strait', 'channel', 'sound'])

function countryName(raw) {
  const name = renamed[raw] ?? raw.replace(/^The /, '')
  return withThe.has(name) ? `the ${name}` : name
}

function waterName(raw) {
  const key = raw.toLowerCase()
  if (oceans[key]) return oceans[key]
  return `the ${waterOverrides[key] ?? raw.replace(/^The /, '')}`
}

// A polygon's or multipolygon's rings, outer and holes alike: the app tests them even-odd.
function ringsOf(geometry) {
  if (geometry?.type === 'Polygon') return geometry.coordinates
  if (geometry?.type === 'MultiPolygon') return geometry.coordinates.flat()
  return []
}

function perpendicular(point, start, end) {
  const dx = end[0] - start[0], dy = end[1] - start[1]
  const length = Math.hypot(dx, dy)
  if (length === 0) return Math.hypot(point[0] - start[0], point[1] - start[1])
  return Math.abs(dy * point[0] - dx * point[1] + end[0] * start[1] - end[1] * start[0]) / length
}

// Douglas–Peucker on an open line.
function simplifyLine(points, tolerance) {
  if (points.length < 3) return points
  let index = 0, farthest = 0
  for (let i = 1; i < points.length - 1; i++) {
    const distance = perpendicular(points[i], points[0], points[points.length - 1])
    if (distance > farthest) { farthest = distance; index = i }
  }
  if (farthest <= tolerance) return [points[0], points[points.length - 1]]
  const left = simplifyLine(points.slice(0, index + 1), tolerance)
  const right = simplifyLine(points.slice(index), tolerance)
  return [...left.slice(0, -1), ...right]
}

// A closed ring, split at the point farthest from its start so each half is an open line.
function simplifyRing(ring, tolerance) {
  const open = ring.slice(0, -1)
  if (open.length < 4) return open.length >= 3 ? open : null
  let split = 0, farthest = 0
  open.forEach((point, i) => {
    const distance = Math.hypot(point[0] - open[0][0], point[1] - open[0][1])
    if (distance > farthest) { farthest = distance; split = i }
  })
  const first = simplifyLine(open.slice(0, split + 1), tolerance)
  const second = simplifyLine([...open.slice(split), open[0]], tolerance)
  const rounded = [...first.slice(0, -1), ...second.slice(0, -1)]
    .map(([lon, lat]) => [Math.round(lon * 100) / 100, Math.round(lat * 100) / 100])
    .filter((point, i, all) => i === 0 || point[0] !== all[i - 1][0] || point[1] !== all[i - 1][1])
  return rounded.length >= 3 ? rounded : null
}

function area(name, kind, country, geometry, tolerance) {
  let rings = ringsOf(geometry).map(ring => simplifyRing(ring, tolerance)).filter(Boolean)
  // Never drop a place: if every ring simplifies away (Malta, Monaco), keep its largest source ring, unsimplified.
  if (rings.length === 0) {
    const shoelace = ring => Math.abs(ring.slice(0, -1).reduce((sum, p, i, open) => { const q = open[(i + 1) % open.length]; return sum + p[0] * q[1] - q[0] * p[1] }, 0)) / 2
    const largest = ringsOf(geometry).reduce((best, ring) => (!best || shoelace(ring) > shoelace(best)) ? ring : best, null)
    const kept = (largest ?? []).slice(0, -1)
      .map(([lon, lat]) => [Math.round(lon * 1000) / 1000, Math.round(lat * 1000) / 1000])
      .filter((point, i, all) => i === 0 || point[0] !== all[i - 1][0] || point[1] !== all[i - 1][1])
    if (kept.length < 3) return null
    rings = [kept]
  }
  const points = rings.flat()
  const box = [
    Math.min(...points.map(p => p[0])), Math.min(...points.map(p => p[1])),
    Math.max(...points.map(p => p[0])), Math.max(...points.map(p => p[1])),
  ]
  return { name, kind, ...(country ? { country } : {}), box, rings: rings.map(ring => ring.flat()) }
}

const countries = read('ne_50m_admin_0_countries').features
const regions = read('ne_50m_admin_1_states_provinces').features.filter(f => ['US', 'CA'].includes(field(f, 'iso_a2')))
const waters = read('ne_50m_geography_marine_polys').features.filter(f => waterClasses.has(String(field(f, 'featurecla') ?? '').toLowerCase()) && (field(f, 'name_en') ?? field(f, 'name')))
const cities = read('ne_10m_populated_places_simple').features
  .filter(f => Number(field(f, 'pop_max')) >= 1_000_000)
  .map(f => ({
    name: field(f, 'name'),
    lat: Math.round(f.geometry.coordinates[1] * 100) / 100,
    lon: Math.round(f.geometry.coordinates[0] * 100) / 100,
  }))

function build(tolerance) {
  const areas = [
    ...regions.map(f => {
      const isUS = field(f, 'iso_a2') === 'US'
      const name = field(f, 'name') === 'District of Columbia' && isUS ? 'the District of Columbia' : field(f, 'name')
      return area(name, isUS ? 'state' : 'province', isUS ? 'the United States' : 'Canada', f.geometry, tolerance)
    }),
    ...countries.map(f => area(countryName(field(f, 'name_en') ?? field(f, 'name')), 'country', null, f.geometry, tolerance)),
    ...waters.map(f => area(waterName(field(f, 'name_en') ?? field(f, 'name')), 'water', null, f.geometry, tolerance)),
  ].filter(Boolean)
  return { source: 'Natural Earth 1:50m and 1:10m, v5.1.2, public domain', areas, cities }
}

let tolerance = 0.01
let geography = build(tolerance)
let json = JSON.stringify(geography)
let rounds = 0
while (Buffer.byteLength(json) > largestFile) {
  if (++rounds > 40) throw new Error(`geography.json is still ${Buffer.byteLength(json)} bytes after 40 rounds (tolerance ${tolerance.toFixed(3)}°); the budget is ${largestFile}.`)
  tolerance *= 1.25
  geography = build(tolerance)
  json = JSON.stringify(geography)
}
writeFileSync(target, json)

const count = kind => geography.areas.filter(a => a.kind === kind).length
console.log(`geography.json: ${count('state')} states, ${count('province')} provinces, ${count('country')} countries, ` +
  `${count('water')} waters, ${geography.cities.length} cities; tolerance ${tolerance.toFixed(3)}°; ${Buffer.byteLength(json)} bytes`)
console.log('Countries:', geography.areas.filter(a => a.kind === 'country').map(a => a.name).join(', '))
