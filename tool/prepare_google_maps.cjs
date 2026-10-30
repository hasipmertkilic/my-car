const fs = require('node:fs');
const path = require('node:path');
const config = JSON.parse(fs.readFileSync(path.join(__dirname, '../config/google_maps.local.json'), 'utf8'));
fs.writeFileSync(path.join(__dirname, '../web/google_maps_config.js'), `window.myCarGoogleMapsKey = ${JSON.stringify(config.webApiKey || '')};\n`);
console.log('Web Google Maps yapılandırması hazır.');
