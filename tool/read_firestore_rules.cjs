const fs = require('node:fs');
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
(async () => {
  await requireAuth({project: 'mycar-f0673', ...getGlobalDefaultAccount()});
  const client = new Client({urlPrefix: 'https://firebaserules.googleapis.com', auth: true});
  const release = await client.get('/v1/projects/mycar-f0673/releases/cloud.firestore');
  const rules = await client.get('/v1/' + release.body.rulesetName);
  for (const file of rules.body.source.files) {
    fs.writeFileSync(path.join(__dirname, '../docs/firestore-before.rules'), file.content);
    console.log(file.content);
  }
})().catch(() => {console.error('Mevcut Firestore kuralları okunamadı.'); process.exitCode = 1;});
