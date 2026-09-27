// Run once before packaging the APK. It converts the archived GTFS CSV files
// into compact per-station JSON so the app does not parse 6 MB of CSV at launch.
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const dataDir = path.join(root, 'data', 'gtfs-source');
const cacheDir = path.join(root, 'data', 'schedule-cache');
const lineNames = { RED: 'Red Line', YELLOW: 'Yellow Line', BLUE: 'Blue Line', GREEN: 'Green Line', VIOLET: 'Violet Line', PINK: 'Pink Line', MAGENTA: 'Magenta Line', GRAY: 'Grey Line', GREY: 'Grey Line', ORANGE: 'Airport Express', 'ORANGE/AIRPORT': 'Airport Express', AQUA: 'Aqua Line', RAPID: 'Rapid Metro' };
const lineColors = { 'Red Line': '#e53935', 'Yellow Line': '#f9a825', 'Blue Line': '#1e88e5', 'Green Line': '#43a047', 'Violet Line': '#8e24aa', 'Pink Line': '#d81b60', 'Magenta Line': '#c2185b', 'Grey Line': '#78909c', 'Airport Express': '#ef6c00', 'Aqua Line': '#26a69a', 'Rapid Metro': '#009688' };

function csv(text) {
  const rows = []; let row = [], cell = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') { if (quoted && text[i + 1] === '"') { cell += '"'; i++; } else quoted = !quoted; }
    else if (c === ',' && !quoted) { row.push(cell); cell = ''; }
    else if ((c === '\n' || c === '\r') && !quoted) { if (c === '\r' && text[i + 1] === '\n') i++; row.push(cell); cell = ''; if (row.some(value => value !== '')) rows.push(row); row = []; }
    else cell += c;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  const headers = rows.shift() || [];
  return rows.map(values => Object.fromEntries(headers.map((key, index) => [key, values[index] ?? ''])));
}
function readCsv(name) { return csv(fs.readFileSync(path.join(dataDir, name), 'utf8').replace(/^\uFEFF/, '')); }
function toSeconds(value) { const [h = 0, m = 0, s = 0] = String(value || '').split(':').map(Number); return h * 3600 + m * 60 + s; }

for (const name of ['stops.txt', 'routes.txt', 'trips.txt', 'stop_times.txt', 'shapes.txt']) if (!fs.existsSync(path.join(dataDir, name))) throw new Error(`Missing GTFS file: ${name}`);
const stops = readCsv('stops.txt').map(row => ({ id: row.stop_id, name: row.stop_name, lat: Number(row.stop_lat), lon: Number(row.stop_lon) }));
const stopById = new Map(stops.map(stop => [stop.id, stop]));
const routes = new Map(readCsv('routes.txt').map(row => {
  const code = (row.route_long_name.split('_')[0] || row.route_short_name.split('_')[0] || '').toUpperCase();
  const name = lineNames[code] || row.route_long_name || row.route_short_name;
  return [row.route_id, { name, color: lineColors[name] || '#64748b' }];
}));
const trips = new Map(readCsv('trips.txt').map(row => [row.trip_id, row]));
const shapesById = new Map();
for (const row of readCsv('shapes.txt')) {
  if (!shapesById.has(row.shape_id)) shapesById.set(row.shape_id, []);
  shapesById.get(row.shape_id).push([Number(row.shape_dist_traveled), Number(row.shape_pt_lon), Number(row.shape_pt_lat), Number(row.shape_pt_sequence)]);
}
const trainShapes = [...shapesById.values()].map(points => {
  points.sort((a, b) => a[3] - b[3]);
  return points.map(([distance, lon, lat]) => [distance, lon, lat]);
});
const shapeIndexes = new Map([...shapesById.keys()].map((shapeId, index) => [shapeId, index]));
const callsByTrip = new Map();
for (const row of readCsv('stop_times.txt')) {
  if (!callsByTrip.has(row.trip_id)) callsByTrip.set(row.trip_id, []);
  callsByTrip.get(row.trip_id).push({ stopId: row.stop_id, arrival: toSeconds(row.arrival_time), departure: toSeconds(row.departure_time), sequence: Number(row.stop_sequence), shapeDistance: row.shape_dist_traveled === '' ? null : Number(row.shape_dist_traveled) });
}
const schedules = new Map(stops.map(stop => [stop.id, { weekday: [], saturday: [], sunday: [] }]));
const stationLines = new Map(stops.map(stop => [stop.id, new Set()]));
const stopIndexes = new Map(stops.map((stop, index) => [stop.id, index]));
const trainServices = { weekday: [], saturday: [], sunday: [] };
const lineIndex = new Map(), destinationIndex = new Map(), trainLines = [], trainDestinations = [];
for (const [tripId, calls] of callsByTrip) {
  const trip = trips.get(tripId); if (!trip || !['weekday', 'saturday', 'sunday'].includes(trip.service_id)) continue;
  calls.sort((a, b) => a.sequence - b.sequence);
  const destination = trip.trip_headsign || stopById.get(calls.at(-1)?.stopId)?.name || 'Terminus';
  const route = routes.get(trip.route_id) || { name: 'Metro', color: '#64748b' };
  for (const call of calls) stationLines.get(call.stopId)?.add(route.name);
  if (!lineIndex.has(route.name)) { lineIndex.set(route.name, trainLines.length); trainLines.push([route.name, route.color]); }
  if (!destinationIndex.has(destination)) { destinationIndex.set(destination, trainDestinations.length); trainDestinations.push(destination); }
  const trainCalls = calls.filter(call => stopIndexes.has(call.stopId)).map(call => [call.arrival, call.departure, stopIndexes.get(call.stopId), Number.isFinite(call.shapeDistance) ? call.shapeDistance : null]);
  const shape = shapeIndexes.get(trip.shape_id) ?? -1;
  if (trainCalls.length > 1) trainServices[trip.service_id].push([tripId, lineIndex.get(route.name), destinationIndex.get(destination), shape, trainCalls]);
  for (const call of calls) schedules.get(call.stopId)?.[trip.service_id]?.push({ arrival: call.arrival, departure: call.departure, line: route.name, color: route.color, destination, tripId });
}
fs.mkdirSync(cacheDir, { recursive: true });
fs.writeFileSync(path.join(cacheDir, 'stations.json'), JSON.stringify(stops.map(stop => ({ ...stop, lines: [...(stationLines.get(stop.id) || [])] }))));
for (const [stopId, board] of schedules) {
  for (const day of Object.values(board)) day.sort((a, b) => a.departure - b.departure);
  fs.writeFileSync(path.join(cacheDir, `${stopId}.json`), JSON.stringify(board));
}
for (const [day, tripsForDay] of Object.entries(trainServices)) {
  fs.writeFileSync(path.join(cacheDir, `trains-${day}.json`), JSON.stringify({ lines: trainLines, destinations: trainDestinations, shapes: trainShapes, trips: tripsForDay }));
}
console.log(`Built cached schedules and scheduled train paths for ${stops.length} stations in ${cacheDir}`);
