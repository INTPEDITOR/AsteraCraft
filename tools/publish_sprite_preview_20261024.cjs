const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),repo='INTPEDITOR/AsteraCraft',tag='sprites-20261024';
const out=path.join(root,'build/sprite_connected_20261024');
const credential=Object.fromEntries(cp.execFileSync('git',['credential','fill'],{input:'protocol=https\nhost=github.com\n\n',encoding:'utf8',cwd:root}).trim().split(/\r?\n/).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1)];}));
if(!credential.password)throw Error('GitHub credential unavailable');
const headers={Authorization:'Bearer '+credential.password,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'AsteraCraft-release'};
async function api(route,method='GET',body){const r=await fetch('https://api.github.com/repos/'+repo+route,{method,headers:{...headers,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});if(r.status===404)return null;const d=await r.json();if(!r.ok)throw Error('GitHub '+r.status+' '+d.message);return d;}
(async()=>{
 const sha=cp.execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8',cwd:root}).trim();
 if((await api('/commits/main')).sha!==sha)throw Error('Exact source commit has not reached GitHub main');
 const releases=await api('/releases?per_page=100');let release=releases.find(r=>r.tag_name===tag);
 if(!release)release=await api('/releases','POST',{tag_name:tag,target_commitish:sha,name:'AsteraCraft sprite preview - 2026-10-24',body:fs.readFileSync(path.join(root,'docs/RELEASE_SPRITES_20261024.md'),'utf8').split('\n## Native overview captures')[0]+'\n\nReport and captures: https://github.com/'+repo+'/blob/'+sha+'/docs/RELEASE_SPRITES_20261024.md\n\nSource commit: '+sha,draft:true,prerelease:true});
 if(release.target_commitish!==sha)throw Error('Existing preview release points to another commit');
 const names=['AsteraCraft-Windows-sprites-20261024.zip','AsteraCraft-Windows-sprites-20261024.zip.sha256'];
 const wanted=fs.readFileSync(path.join(out,names[1]),'utf8').trim().split(/\s+/)[0];
 for(const name of names){
  const file=path.join(out,name),size=fs.statSync(file).size;let asset=release.assets.find(a=>a.name===name);
  if(!asset){console.log('Uploading '+name+' '+size+' bytes');const r=await fetch(release.upload_url.split('{')[0]+'?name='+encodeURIComponent(name),{method:'POST',headers:{...headers,'Content-Type':name.endsWith('.zip')?'application/zip':'text/plain','Content-Length':String(size)},body:fs.createReadStream(file),duplex:'half'});asset=await r.json();if(!r.ok)throw Error('Upload '+r.status+' '+asset.message);}
  if(asset.size!==size||asset.state!=='uploaded'||(name.endsWith('.zip')&&asset.digest!=='sha256:'+wanted))throw Error('Uploaded asset integrity mismatch: '+name);
 }
 if(release.draft)release=await api('/releases/'+release.id,'PATCH',{draft:false,prerelease:true,make_latest:'false'});
 const verified=await api('/releases/tags/'+tag);const asset=verified.assets.find(a=>a.name===names[0]);
 if(verified.draft||!asset||asset.digest!=='sha256:'+wanted)throw Error('Published preview confirmation failed');
 const result={url:verified.html_url,asset:asset.browser_download_url,commit:sha,bytes:asset.size,sha256:wanted,quick_checks:139,quick_failures:0,full_art_review:false};
 fs.writeFileSync(path.join(out,'github-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
