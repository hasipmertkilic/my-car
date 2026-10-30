const fs = require('node:fs');
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
(async () => {
  const configPath = process.argv[2] ? path.resolve(process.argv[2]) : path.join(__dirname, '../config/google_maps.local.json');
  const config = JSON.parse(fs.readFileSync(configPath));
  const account = getGlobalDefaultAccount();
  await requireAuth({project: 'mycar-f0673', ...account});
  const client = new Client({urlPrefix: 'https://apikeys.googleapis.com', auth: true});
  const lookup = await client.get('/v2/keys:lookupKey', {queryParams: {keyString: config.webApiKey}});
  const key = (await client.get('/v2/' + lookup.body.name)).body;
  const restrictions = key.restrictions || {};
  const usage = new Client({urlPrefix: 'https://serviceusage.googleapis.com', auth: true});
  const project = lookup.body.parent.split('/locations/')[0];
  const states = await Promise.allSettled(['maps-backend.googleapis.com', 'maps-android-backend.googleapis.com'].map(async name => {
    const result = await usage.get('/v1/' + project + '/services/' + name);
    return result.body.state;
  }));
  let billingEnabled = null;
  let projectId = project;
  try {
    const manager = new Client({urlPrefix: 'https://cloudresourcemanager.googleapis.com', auth: true});
    const details = (await manager.get('/v1/' + project)).body;
    projectId = details.projectId;
    const billing = new Client({urlPrefix: 'https://cloudbilling.googleapis.com', auth: true});
    billingEnabled = (await billing.get('/v1/projects/' + details.projectId + '/billingInfo')).body.billingEnabled === true;
  } catch (_) { /* Salt okunur denetim kullanıcının izinlerine bağlıdır. */ }
  // Demo projelerinde billingEnabled=false web denemesinin çalışmadığını göstermez.
  console.log(JSON.stringify({project, projectId, demoProject: projectId.startsWith('gmp-demo-project-'), browser: restrictions.browserKeyRestrictions || null, android: restrictions.androidKeyRestrictions || null, services: restrictions.apiTargets?.map(target => target.service) || [], webApiState: states[0].status === 'fulfilled' ? states[0].value : 'unknown', androidApiState: states[1].status === 'fulfilled' ? states[1].value : 'unknown', billingEnabled}));
})().catch(() => {console.error('Maps anahtarının platform kısıtlamaları okunamadı.'); process.exitCode = 1;});
