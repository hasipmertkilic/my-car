const fs = require('node:fs');
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
(async () => {
  const configFile = path.join(__dirname, '../config/google_maps.local.json');
  const config = JSON.parse(fs.readFileSync(configFile));
  await requireAuth({project: 'mycar-f0673', ...getGlobalDefaultAccount()});
  const keys = new Client({urlPrefix: 'https://apikeys.googleapis.com', auth: true});
  const lookup = (await keys.get('/v2/keys:lookupKey', {queryParams: {keyString: config.webApiKey}})).body;
  const project = lookup.parent.split('/locations/')[0];
  if (project !== 'projects/212856320594') throw new Error('Beklenmeyen proje.');
  const usage = new Client({urlPrefix: 'https://serviceusage.googleapis.com', auth: true});
  const target = '/v1/' + project + '/services/maps-android-backend.googleapis.com';
  const service = (await usage.get(target)).body;
  if (service.config?.name !== 'maps-android-backend.googleapis.com') throw new Error('Beklenmeyen hizmet.');
  if (service.state !== 'ENABLED') await usage.post(target + ':enable', {});
  const key = (await keys.get('/v2/' + lookup.name)).body;
  const restrictions = key.restrictions || {};
  const targets = restrictions.apiTargets || [];
  if (targets.length && !targets.some(t => t.service === 'maps-android-backend.googleapis.com')) {
    await keys.patch('/v2/' + lookup.name, {name: key.name, etag: key.etag, restrictions: {...restrictions, apiTargets: [...targets, {service: 'maps-android-backend.googleapis.com'}]}}, {queryParams: {updateMask: 'restrictions'}});
  }
  config.androidApiKey = config.webApiKey;
  fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
  console.log('Android Maps hizmeti ve anahtar yapılandırması güncellendi.');
})().catch(() => {console.error('Android Maps yapılandırması tamamlanamadı.'); process.exitCode = 1;});
