const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto');
const repo='INTPEDITOR/AsteraCraft',tag='v0.6.0',root=path.resolve(__dirname,'..');
const file=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.6.0-20261021.zip');
const credential=Object.fromEntries(cp.execFileSync('git',['credential','fill'],{input:'protocol=https\nhost=github.com\n\n',encoding:'utf8',cwd:root}).trim().split(/\r?\n/).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1)]}));
const headers={Authorization:'Bearer '+credential.password,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'AsteraCraft-release'};
async function api(route,method='GET',body){const r=await fetch('https://api.github.com/repos/'+repo+route,{method,headers:{...headers,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});if(r.status===404)return null;const d=await r.json();if(!r.ok)throw Error('GitHub '+r.status+' '+d.message);return d;}
async function upload(release,file,mime){const size=fs.statSync(file).size,hash=crypto.createHash('sha256');for await(const chunk of fs.createReadStream(file))hash.update(chunk);const digest='sha256:'+hash.digest('hex'),name=path.basename(file);let asset=release.assets.find(x=>x.name===name);
 if(!asset){console.log('Uploading '+name+' ('+size+' bytes)');const r=await fetch(release.upload_url.split('{')[0]+'?name='+encodeURIComponent(name),{method:'POST',headers:{...headers,'Content-Type':mime,'Content-Length':String(size)},body:fs.createReadStream(file),duplex:'half'});asset=await r.json();if(!r.ok)throw Error('Upload '+r.status+' '+asset.message);}
 if(asset.size!==size||asset.state!=='uploaded'||asset.digest!==digest)throw Error('Release asset integrity mismatch: '+name);return asset;
}
(async()=>{
 const sha=cp.execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8',cwd:root}).trim(),remote=await api('/commits/main');if(remote.sha!==sha)throw Error('Push the exact tested commit before publishing');
 const digest=fs.readFileSync(file+'.sha256','utf8').split(/\s/)[0];
 let release=await api('/releases/tags/'+tag);
 if(!release)release=await api('/releases','POST',{tag_name:tag,target_commitish:sha,name:'AsteraCraft v0.6.0',body:fs.readFileSync(path.join(root,'docs/changes-v060.txt'),'utf8')+'\n\nWindows ZIP을 내려받아 압축을 풀고 폴더 안의 AsteraCraft.exe를 실행하세요.\n\nSHA256: `'+digest+'`',draft:true,prerelease:false});
 if(release.target_commitish!==sha&&release.target_commitish!=='main')throw Error('Existing release points to another commit');
 const asset=await upload(release,file,'application/zip');await upload(release,file+'.sha256','text/plain');
 if(release.draft)release=await api('/releases/'+release.id,'PATCH',{draft:false,make_latest:'true'});
 const verified=await api('/releases/tags/'+tag);if(verified.draft||!verified.assets.some(a=>a.name===path.basename(file)&&a.digest===asset.digest))throw Error('Published release verification failed');
 const publishedAsset=verified.assets.find(a=>a.name===path.basename(file));
 const result={url:verified.html_url,release_id:verified.id,commit:sha,asset:publishedAsset.browser_download_url,bytes:publishedAsset.size,digest:publishedAsset.digest};fs.writeFileSync(path.join(root,'build/github-v060-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e.message);process.exitCode=1});
