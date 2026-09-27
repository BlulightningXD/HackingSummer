const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = __dirname;
const envPath = path.join(root, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*OTD_API_KEY\s*=\s*(.*?)\s*$/);
    if (match && !process.env.OTD_API_KEY) process.env.OTD_API_KEY = match[1].replace(/^['"]|['"]$/g, '');
  }
}

function fields(bytes) {
  const out = [];
  let i = 0;
  const varint = () => {
    let n = 0n, shift = 0n;
    while (i < bytes.length) {
      const b = bytes[i++]; n |= BigInt(b & 127) << shift;
      if (!(b & 128)) return Number(n);
      shift += 7n;
      if (shift > 63n) throw new Error('Invalid protobuf varint');
    }
    throw new Error('Truncated protobuf varint');
  };
  while (i < bytes.length) {
    const tag = varint(), id = tag >>> 3, wire = tag & 7;
    if (wire === 0) out.push({ id, wire, value: varint() });
    else if (wire === 1) { out.push({ id, wire, value: bytes.subarray(i, i + 8) }); i += 8; }
    else if (wire === 2) { const size = varint(); out.push({ id, wire, value: bytes.subarray(i, i + size) }); i += size; }
    else if (wire === 5) { out.push({ id, wire, value: bytes.subarray(i, i + 4) }); i += 4; }
    else throw new Error('Unsupported protobuf wire type');
    if (i > bytes.length) throw new Error('Truncated protobuf field');
  }
  return out;
}
const all = (fs, id) => fs.filter(f => f.id === id);
const first = (fs, id) => fs.find(f => f.id === id)?.value;
const str = value => value ? Buffer.from(value).toString('utf8') : '';
function float(value) { return value?.length === 4 ? value.readFloatLE(0) : null; }
function decodeFeed(buffer) {
  const entities = all(fields(buffer), 2).map(f => fields(f.value));
  return entities.map(entity => {
    const vehicleBytes = first(entity, 4);
    if (!vehicleBytes) return null;
    const vehicle = fields(vehicleBytes), positionBytes = first(vehicle, 2);
    if (!positionBytes) return null;
    const position = fields(positionBytes), lat = float(first(position, 1)), lon = float(first(position, 2));
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
    const tripBytes = first(vehicle, 1), trip = tripBytes ? fields(tripBytes) : [];
    const descriptorBytes = first(vehicle, 8), descriptor = descriptorBytes ? fields(descriptorBytes) : [];
    const status = first(vehicle, 5);
    return {
      id: str(first(entity, 1)) || str(first(descriptor, 1)) || `vehicle-${lat}-${lon}`,
      label: str(first(descriptor, 2)) || str(first(descriptor, 1)) || 'Metro train',
      routeId: str(first(trip, 5)), stopId: str(first(vehicle, 4)),
      latitude: lat, longitude: lon,
      bearing: float(first(position, 3)), speed: float(first(position, 5)),
      currentStatus: status === 0 ? 'INCOMING_AT' : status === 1 ? 'STOPPED_AT' : status === 2 ? 'IN_TRANSIT_TO' : 'UNKNOWN',
      timestamp: Number(first(vehicle, 6) || 0)
    };
  }).filter(Boolean);
}

const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8' };
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/api/live-trains') {
    if (!process.env.OTD_API_KEY) { res.writeHead(503, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: 'Add OTD_API_KEY to the local .env file, then restart Metro One.' })); return; }
    try {
      const upstream = await fetch(`https://otd.delhi.gov.in/api/realtime/VehiclePositions.pb?key=${encodeURIComponent(process.env.OTD_API_KEY)}`, { headers: { Accept: 'application/x-protobuf, application/octet-stream' }, signal: AbortSignal.timeout(15000) });
      if (!upstream.ok) throw new Error(`OTD returned HTTP ${upstream.status}`);
      const trains = decodeFeed(Buffer.from(await upstream.arrayBuffer()));
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ vehicles: trains, feedType: 'bus', fetchedAt: new Date().toISOString(), source: 'Delhi Open Transit Data' }));
    } catch (error) {
      res.writeHead(502, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ error: `Could not read the OTD vehicle feed: ${error.message}` }));
    }
    return;
  }
  const requested = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1));
  const file = path.resolve(root, requested);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end('Forbidden'); return; }
  fs.readFile(file, (error, data) => {
    if (error) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }); res.end(data);
  });
});
server.listen(4177, '127.0.0.1', () => console.log('Metro One is running at http://127.0.0.1:4177'));
