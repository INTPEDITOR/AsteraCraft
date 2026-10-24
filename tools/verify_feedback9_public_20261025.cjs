const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback9_20261025');
const expected=JSON.parse(fs.readFileSync(path.join(out,'package-result.json'),'utf8'));
const headers={Accept:'application/vnd.github+json','User-Agent':'AsteraCraft-public-release-verification'};
async function release(tag){const response=await fetch('https://api.github.com/repos/INTPEDITOR/AsteraCraft/releases/tags/'+tag,{headers});if(!response.ok)throw Error('Public release lookup failed: '+response.status);return response.json();}
(async()=>{
 const [current,previous]=await Promise.all([release('feedback9-20261025'),release('feedback8-20261025')]);
 const asset=current.assets.find(a=>a.name==='AsteraCraft-Windows-feedback9-20261025.zip');
 if(current.draft||!asset||asset.state!=='uploaded'||asset.size!==expected.bytes||asset.digest!=='sha256:'+expected.sha256)throw Error('Published package identity mismatch');
 if(previous.draft||!previous.assets.some(a=>a.name==='AsteraCraft-Windows-feedback8-20261025.zip'))throw Error('Previous release was not preserved');
 const response=await fetch(asset.browser_download_url,{method:'HEAD',redirect:'follow'});
 if(!response.ok)throw Error('Public archive HEAD failed: '+response.status);
 const result={passed:true,url:current.html_url,asset:asset.browser_download_url,public_head_status:response.status,bytes:expected.bytes,sha256:expected.sha256,previous_release_preserved:true,previous_release:previous.html_url,scope:'Public release metadata digest and byte count match the local CRC-checked ZIP; public download HEAD succeeds. No full public archive download.'};
 fs.writeFileSync(path.join(out,'published-verification.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
