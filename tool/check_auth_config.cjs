// Mevcut Firebase CLI oturumuyla yalnızca Authentication yapılandırmasını okur.
const path = require('node:path');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const {getGlobalDefaultAccount} = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const {Client} = require(path.join(cli, 'apiv2'));
(async () => {
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('Firebase oturumu bulunamadı.');
  await requireAuth({project: 'mycar-f0673', ...account});
  const client = new Client({urlPrefix: 'https://identitytoolkit.googleapis.com', auth: true});
  const {body} = await client.get('/admin/v2/projects/mycar-f0673/config', {headers: {'x-goog-user-project': 'mycar-f0673'}});
  const emails = new Map();
  let pageToken;
  let accountCount = 0;
  do {
    const result = await client.get('/v1/projects/mycar-f0673/accounts:batchGet', {
      queryParams: {maxResults: 1000, ...(pageToken ? {nextPageToken: pageToken} : {})},
    });
    for (const user of result.body.users || []) {
      accountCount++;
      if (user.email) {
        const key = user.email.trim().toLowerCase();
        emails.set(key, (emails.get(key) || 0) + 1);
      }
    }
    pageToken = result.body.nextPageToken;
  } while (pageToken);
  console.log(JSON.stringify({emailPasswordEnabled: body.signIn?.email?.enabled === true, allowDuplicateEmails: body.signIn?.allowDuplicateEmails === true, accountCount, duplicateEmailGroups: [...emails.values()].filter(count => count > 1).length, localhostAuthorized: body.authorizedDomains?.includes('localhost')}));
})().catch(() => {console.error('Authentication yapılandırması okunamadı.'); process.exitCode = 1;});
