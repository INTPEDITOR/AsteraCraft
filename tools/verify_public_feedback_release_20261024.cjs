const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=process.argv[2],tag=process.argv[3],previousTag=process.argv[4];
for(const value of [folder,tag,previousTag])if(!/^[a-z0-9_-]{1,80}$/.test(value||''))throw Error('Invalid release identifier');
const out=path.join(root,'build',folder),local=JSON.parse(fs.readFileSync(path.join(out,'package-result.json'),'utf8'));
const credential=Object.fromEntries(cp.execFileSync('git',['credential','fill'],{input:'protocol=https\nhost=github.com\n\n',encoding:'utf8',cwd:root}).trim().split(/\r?\n/).map(s=>{const i=s.indexOf('=');return[s.slice(0,i),s.slice(i+1)];}));
const headers={Authorization:'Bearer '+credential.password,Accept:'application/vnd.github+json','User-Agent':'AsteraCraft-release-verification'};
async function read(name){const response=await fetch('https://api.github.com/repos/INTPEDITOR/AsteraCraft/releases/tags/'+name,{headers});if(!response.ok)throw Error('Public release lookup failed '+response.status);return response.json();}
(async()=>{
 const release=await read(tag),previous=await read(previousTag),asset=release.assets.find(a=>a.name==='AsteraCraft-Windows-'+tag+'.zip');
 if(release.draft||!asset||asset.digest!=='sha256:'+local.sha256||asset.size!==local.bytes)throw Error('Published package metadata mismatch');
 if(previous.draft||!previous.assets.some(a=>a.name==='AsteraCraft-Windows-'+previousTag+'.zip'))throw Error('Previous release was not preserved');
 const head=await fetch(asset.browser_download_url,{method:'HEAD'});
 if(!head.ok||Number(head.headers.get('content-length'))!==local.bytes)throw Error('Public package HEAD verification failed');
 const result={passed:true,url:release.html_url,asset:asset.browser_download_url,public_head_status:head.status,bytes:asset.size,sha256:local.sha256,previous_release_preserved:true,previous_release:previous.html_url,scope:'GitHub published asset digest and byte count match the local CRC-checked package; public download HEAD succeeds. No full public archive download.'};
 fs.writeFileSync(path.join(out,'published-verification.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
