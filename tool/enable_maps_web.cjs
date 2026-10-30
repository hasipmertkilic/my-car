const fs = require('node:fs');
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
(async () => {
  const config = JSON.parse(fs.readFileSync(path.join(__dirname, '../config/google_maps.local.json')));
  await requireAuth({project: 'mycar-f0673', ...getGlobalDefaultAccount()});
  const keys = new Client({urlPrefix: 'https://apikeys.googleapis.com', auth: true});
  const lookup = await keys.get('/v2/keys:lookupKey', {queryParams: {keyString: config.webApiKey}});
  const project = lookup.body.parent.split('/locations/')[0];
  if (project !== 'projects/1026841621540') throw new Error('Beklenmeyen proje.');
  const usage = new Client({urlPrefix: 'https://serviceusage.googleapis.com', auth: true});
  const target = '/v1/' + project + '/services/maps-backend.googleapis.com';
  const service = (await usage.get(target)).body;
  if (service.config?.name !== 'maps-backend.googleapis.com') throw new Error('Beklenmeyen hizmet.');
  if (service.state === 'ENABLED') { console.log('Maps JavaScript API zaten etkin.'); return; }
  const operation = (await usage.post(target + ':enable', {})).body;
  fs.writeFileSync(path.join(__dirname, '../config/maps_enable_operation.json'), JSON.stringify({name: operation.name}));
  console.log(JSON.stringify({service: service.config.title, operation: operation.name, done: operation.done === true}));
})().catch(() => {console.error('Maps JavaScript API etkinleştirilemedi.'); process.exitCode = 1;});
