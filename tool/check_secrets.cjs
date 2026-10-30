const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const files = execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], {encoding:'utf8'}).split('\0').filter(Boolean);
const patterns = [/(?<![0-9A-Za-z_-])AIza[0-9A-Za-z_-]{35}(?![0-9A-Za-z_-])/, /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/, /"type"\s*:\s*"service_account"/, /gh[pousr]_[A-Za-z0-9]{30,}/, /github_pat_[A-Za-z0-9_]{50,}/];
let found = false;
for (const path of new Set(files)) {
  if (!fs.existsSync(path) || !fs.statSync(path).isFile()) continue;
  const bytes=fs.readFileSync(path);
  if (bytes.includes(0)) continue;
  const lines=bytes.toString('utf8').split(/\r?\n/);
  lines.forEach((line,index)=>{if(patterns.some(pattern=>pattern.test(line))){console.error(`${path}:${index+1}: Olası anahtar veya özel kimlik bilgisi.`);found=true;}});
}
if(found)process.exitCode=1;
else console.log('Git tarafından izlenen ve eklenebilir dosyalarda bilinen anahtar biçimleri bulunmadı. Git geçmişi bu kontrolün kapsamı dışındadır.');

