const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const cacheDir = path.join(root, 'data', 'schedule-cache');
const PORT = Number(process.env.PORT || 4179);
const lineNames = { RED: 'Red Line', YELLOW: 'Yellow Line', BLUE: 'Blue Line', GREEN: 'Green Line', VIOLET: 'Violet Line', PINK: 'Pink Line', MAGENTA: 'Magenta Line', GRAY: 'Grey Line', GREY: 'Grey Line', ORANGE: 'Airport Express', 'ORANGE/AIRPORT': 'Airport Express', AQUA: 'Aqua Line', RAPID: 'Rapid Metro' };
const lineColors = { 'Red Line': '#e53935', 'Yellow Line': '#f9a825', 'Blue Line': '#1e88e5', 'Green Line': '#43a047', 'Violet Line': '#8e24aa', 'Pink Line': '#d81b60', 'Magenta Line': '#c2185b', 'Grey Line': '#78909c', 'Airport Express': '#ef6c00', 'Aqua Line': '#26a69a', 'Rapid Metro': '#009688' };
const scheduleInfo = { snapshotDate: '2023-08-10', source: 'Delhi Open Transit Data DMRC static GTFS (archived snapshot)', cached: true };
const stops = JSON.parse(fs.readFileSync(path.join(cacheDir, 'stations.json'), 'utf8'));
scheduleInfo.stationCount = stops.length;
const trainDataByDay = new Map(), stationScheduleCache = new Map();
function loadStationSchedule(stopId) {
  let board = stationScheduleCache.get(stopId);
  if (!board) { board = JSON.parse(fs.readFileSync(path.join(cacheDir, `${stopId}.json`), 'utf8')); stationScheduleCache.set(stopId, board); }
  return board;
}
function loadTrainFeed(dayType) {
  let feed = trainDataByDay.get(dayType);
  if (!feed) { feed = JSON.parse(fs.readFileSync(path.join(cacheDir, `trains-${dayType}.json`), 'utf8')); trainDataByDay.set(dayType, feed); }
  return feed;
}
function activeTrains(feed, at, excludedLines = new Set(), includedLines = new Set()) {
  const trains = [];
  for (const [id, lineIndex, destinationIndex, shapeIndex, calls] of feed.trips) {
    const [line, color] = feed.lines[lineIndex];
    if (excludedLines.has(line) || (includedLines.size && !includedLines.has(line))) continue;
    let motion = null;
    for (let index = 0; index < calls.length; index++) {
      const [arrival, departure, stationIndex, shapeDistance] = calls[index], station = stops[stationIndex];
      if (!station) continue;
      if (departure > arrival && at >= arrival && at < departure) {
        motion = { path: [[station.lon, station.lat]], fromTime: arrival, toTime: departure, station: station.name };
        break;
      }
      const next = calls[index + 1];
      if (next && at >= departure && at < next[0]) {
        const nextStation = stops[next[2]];
        if (nextStation) {
          const from = [station.lon, station.lat], to = [nextStation.lon, nextStation.lat];
          const endShapeDistance = next[3]; let pathPoints = [from, to];
          if (shapeIndex >= 0 && Number.isFinite(shapeDistance) && Number.isFinite(endShapeDistance)) {
            const shape = feed.shapes[shapeIndex] || [], ascending = endShapeDistance >= shapeDistance;
            const between = shape.filter(point => ascending ? point[0] > shapeDistance && point[0] < endShapeDistance : point[0] < shapeDistance && point[0] > endShapeDistance);
            between.sort((a, b) => ascending ? a[0] - b[0] : b[0] - a[0]);
            pathPoints = [from, ...between.map(point => [point[1], point[2]]), to];
          }
          motion = { path: pathPoints, fromTime: departure, toTime: next[0], station: null };
        }
        break;
      }
    }
    if (motion) trains.push({ id, line, color, destination: feed.destinations[destinationIndex], ...motion });
  }
  return trains;
}
function trainFeedsForDay(dayType) {
  const primary = loadTrainFeed(dayType), feeds = [{ feed: primary, excludedLines: new Set() }], activeLines = new Set(primary.trips.map(trip => primary.lines[trip[1]][0]));
  let fallbackLines = [];
  if (dayType !== 'weekday') {
    const weekday = loadTrainFeed('weekday');
    fallbackLines = [...new Set(weekday.trips.map(trip => weekday.lines[trip[1]][0]))].filter(line => !activeLines.has(line));
    if (fallbackLines.length) feeds.push({ feed: weekday, excludedLines: activeLines });
  }
  return { feeds, fallbackLines };
}
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml' };
function json(res, code, body, cache = 'no-store') { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': cache }); res.end(JSON.stringify(body)); }
const server = http.createServer((req, res) => {
  let url;
  try { url = new URL(req.url, `http://127.0.0.1:${PORT}`); }
  catch { res.writeHead(400); res.end('Bad request'); return; }
  if (url.pathname === '/api/metro-stations') { json(res, 200, { ...scheduleInfo, stations: stops }, 'public, max-age=3600'); return; }
  if (url.pathname === '/api/metro-schedule') {
    const stopId = url.searchParams.get('stopId') || '', dayType = url.searchParams.get('dayType') || 'weekday', after = Number(url.searchParams.get('after') || 0), count = Math.min(12, Math.max(1, Number(url.searchParams.get('count') || 8))), stop = stops.find(item => item.id === stopId);
    if (!stop || !['weekday', 'saturday', 'sunday'].includes(dayType) || !Number.isFinite(after)) { json(res, 400, { error: 'Choose a station and a valid service day.' }); return; }
    try { const board = loadStationSchedule(stopId)[dayType]; if (!board) { json(res, 404, { error: 'Schedule data is unavailable for that station.' }); return; } json(res, 200, { ...scheduleInfo, stop, dayType, departures: board.filter(item => item.departure >= after).slice(0, count) }); }
    catch { json(res, 503, { error: 'Scheduled train data is unavailable.' }); }
    return;
  }
  if (url.pathname === '/api/metro-trains') {
    const dayType = url.searchParams.get('dayType') || 'weekday', at = Number(url.searchParams.get('at') || 0), allowedLines = new Set((url.searchParams.get('lines') || '').split(',').filter(Boolean));
    if (!['weekday', 'saturday', 'sunday'].includes(dayType) || !Number.isFinite(at)) { json(res, 400, { error: 'Choose a valid service day and time.' }); return; }
    try { const selection = trainFeedsForDay(dayType), trains = []; for (const source of selection.feeds) trains.push(...activeTrains(source.feed, at, source.excludedLines, allowedLines)); json(res, 200, { ...scheduleInfo, dayType, at, fallbackLines: selection.fallbackLines, trains }); }
    catch { json(res, 503, { error: 'Scheduled train paths are unavailable. Run build-schedule-cache.js.' }); }
    return;
  }
  if (url.pathname === '/api/metro-arrivals') {
    const stopId = url.searchParams.get('stopId') || '', dayType = url.searchParams.get('dayType') || 'weekday', at = Number(url.searchParams.get('at') || 0), allowedLines = new Set((url.searchParams.get('lines') || '').split(',').filter(Boolean)), stopIndex = stops.findIndex(item => item.id === stopId), stop = stops[stopIndex];
    if (!stop || !['weekday', 'saturday', 'sunday'].includes(dayType) || !Number.isFinite(at)) { json(res, 400, { error: 'Choose a station and a valid service time.' }); return; }
    try {
      const selection = trainFeedsForDay(dayType), arrivals = [], board = loadStationSchedule(stopId);
      for (const source of selection.feeds) {
        const service = source.feed === selection.feeds[0].feed ? dayType : 'weekday';
        for (const item of board[service] || []) {
          if (item.arrival < at || source.excludedLines.has(item.line) || (allowedLines.size && !allowedLines.has(item.line))) continue;
          arrivals.push({ id: String(item.tripId), line: item.line, color: item.color, destination: item.destination, arrival: item.arrival, waitSeconds: item.arrival - at, station: stop.name });
        }
      }
      arrivals.sort((a, b) => a.arrival - b.arrival); json(res, 200, { ...scheduleInfo, dayType, at, stop, fallbackLines: selection.fallbackLines, arrivals: arrivals.slice(0, 8) });
    } catch { json(res, 503, { error: 'Scheduled train arrivals are unavailable.' }); }
    return;
  }
  let requested;
  try { requested = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1)); }
  catch { res.writeHead(400); res.end('Bad request'); return; }
  const file = path.resolve(root, requested);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end('Forbidden'); return; }
  fs.readFile(file, (error, bytes) => { if (error) { res.writeHead(404); res.end('Not found'); return; } res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream' }); res.end(bytes); });
});
server.listen(PORT, '127.0.0.1', () => console.log(`Live Navigator is running at http://127.0.0.1:${PORT} (Metro schedule snapshot from 10 Aug 2023; not live train telemetry)`));