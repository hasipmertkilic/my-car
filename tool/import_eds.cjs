// Import only public marker facts. Never evaluate the source page JavaScript.
const fs = require('node:fs');
const crypto = require('node:crypto');
const input = process.argv[2];
if (!input) throw new Error('Usage: node tool/import_eds.cjs downloaded-egm-page.html');
const html = fs.readFileSync(input, 'utf8');
const block = html.match(/var markers\s*=\s*\[([\s\S]*?)\];/);
if (!block) throw new Error('Public marker list missing; existing data unchanged');
const pattern = /"Aciklama"\s*:\s*'([\s\S]*?)'\s*,\s*"lat"\s*:\s*'([^']+)'\s*,\s*"lng"\s*:\s*'([^']+)'/g;
const seen = new Set();
const points = [];
let rejected = 0;
for (const m of block[1].matchAll(pattern)) {
  const latitude = Number(m[2]), longitude = Number(m[3]);
  const name = m[1].replace(/\\'/g, "'").replace(/\s+/g, ' ').trim();
  // Published list is Turkey only. Reject zero/swapped/outlier coordinates.
  if (!name || !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      latitude < 35.5 || latitude > 42.5 || longitude < 25.5 || longitude > 45) {
    rejected++; continue;
  }
  const identity = `${latitude}|${longitude}|${name}`;
  if (seen.has(identity)) continue;
  seen.add(identity);
  points.push({id: crypto.createHash('sha256').update(identity).digest('hex').slice(0,16),
    name, latitude, longitude});
}
if (points.length < 100) throw new Error('Unexpectedly small list; existing data unchanged');
fs.mkdirSync('assets/eds', {recursive:true});
fs.writeFileSync('assets/eds/egm_points.json', JSON.stringify({
  source:'https://onlineislemler.egm.gov.tr/trafik/sayfalar/edsharita.aspx',
  retrievedAt:new Date().toISOString().slice(0,10), sourceUpdatedAt:null,
  coverage:'EGM kamuya açık haritasındaki EDS noktaları; tüm denetimleri kapsamaz.',
  points,
}));
console.log(`Imported ${points.length} public points; rejected ${rejected} invalid coordinates.`);
