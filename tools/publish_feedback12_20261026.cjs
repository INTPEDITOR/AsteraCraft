const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),repo='INTPEDITOR/AsteraCraft',tag='feedback12-20261026';
const out=path.join(root,'build/feedback12_20261026');
const body=fs.readFileSync(path.join(out,'release-notes.md'),'utf8');
const validation=JSON.parse(fs.readFileSync(path.join(out,'release-validation.json'),'utf8'));
if(!validation.passed)throw Error('Release validation has not passed');
if(JSON.parse(fs.readFileSync(path.join(root,'data/update_channel.json'),'utf8')).tag!==tag)throw Error('Packed update channel must match this release tag');
const credential=Object.fromEntries(cp.execFileSync('git',['credential','fill'],{input:'protocol=https\nhost=github.com\n\n',encoding:'utf8',cwd:root}).trim().split(/\r?\n/).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1)];}));
if(!credential.password)throw Error('GitHub credential unavailable');
const headers={Authorization:'Bearer '+credential.password,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'AsteraCraft-release'};
async function api(route,method='GET',data){
 const response=await fetch('https://api.github.com/repos/'+repo+route,{method,headers:{...headers,'Content-Type':'application/json'},body:data?JSON.stringify(data):undefined});
 if(response.status===404)return null;
 const result=await response.json();if(!response.ok)throw Error('GitHub '+response.status+' '+result.message);return result;
}
(async()=>{
 const sha=cp.execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8',cwd:root}).trim();
 if(validation.commit!==sha)throw Error('Validated build does not match current source commit');
 if((await api('/commits/main')).sha!==sha)throw Error('Exact source commit has not reached GitHub main');
 const releases=await api('/releases?per_page=100');let release=releases.find(r=>r.tag_name===tag);
 if(!release)release=await api('/releases','POST',{tag_name:tag,target_commitish:sha,name:'AsteraCraft 전술·헬·일꾼 중앙 통행 수정판 - 2026-10-26',body:body+'\n\nSource commit: '+sha,draft:true,prerelease:true});
 if(release.target_commitish!==sha){
  const changed=cp.execFileSync('git',['diff','--name-only',release.target_commitish,sha],{encoding:'utf8',cwd:root}).trim().split(/\r?\n/).filter(Boolean);
  if(!release.draft||release.assets.length||changed.some(file=>file!=='tools/publish_feedback12_20261026.cjs'))throw Error('Existing release points to another runtime source commit');
  release=await api('/releases/'+release.id,'PATCH',{tag_name:tag,target_commitish:sha,body:body+'\n\nSource commit: '+sha});
  if(release.target_commitish!==sha)throw Error('Draft source update was not applied');
 }
 const names=['AsteraCraft-Windows-'+tag+'.zip','AsteraCraft-Windows-'+tag+'.zip.sha256'];
 const wanted=fs.readFileSync(path.join(out,names[1]),'utf8').trim().split(/\s+/)[0];
 for(const name of names){
  const file=path.join(out,name),size=fs.statSync(file).size;let asset=release.assets.find(a=>a.name===name);
  if(!asset){
   console.log('Uploading '+name+' '+size+' bytes');
   const stream=fs.createReadStream(file);
   // Reading bytesRead does not consume the body before fetch attaches to it.
   const progress=setInterval(()=>console.log('UPLOAD_PROGRESS '+Math.floor(stream.bytesRead/size*100)+'% '+name),30000);
   let response;
   try{response=await fetch(release.upload_url.split('{')[0]+'?name='+encodeURIComponent(name),{method:'POST',headers:{...headers,'Content-Type':name.endsWith('.zip')?'application/zip':'text/plain','Content-Length':String(size)},body:stream,duplex:'half'});}
   finally{clearInterval(progress);}
   asset=await response.json();if(!response.ok)throw Error('Upload '+response.status+' '+asset.message);
  }
  if(asset.size!==size||asset.state!=='uploaded'||(name.endsWith('.zip')&&asset.digest!=='sha256:'+wanted))throw Error('Uploaded asset integrity mismatch: '+name);
 }
 if(release.draft)release=await api('/releases/'+release.id,'PATCH',{tag_name:tag,target_commitish:sha,draft:false,prerelease:true,make_latest:'false'});
 const verified=await api('/releases/'+release.id);const asset=verified?.assets.find(a=>a.name===names[0]);
 if(!verified||verified.tag_name!==tag||verified.draft||!asset||asset.digest!=='sha256:'+wanted)throw Error('Published release confirmation failed');
 const result={url:verified.html_url,asset:asset.browser_download_url,commit:sha,bytes:asset.size,sha256:wanted,validation};
 fs.writeFileSync(path.join(out,'github-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
