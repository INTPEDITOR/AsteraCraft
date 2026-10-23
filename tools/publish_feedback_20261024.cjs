const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),repo='INTPEDITOR/AsteraCraft',tag='feedback-20261024';
const out=path.join(root,'build/feedback_fixed_20261024');
const credential=Object.fromEntries(cp.execFileSync('git',['credential','fill'],{input:'protocol=https\nhost=github.com\n\n',encoding:'utf8',cwd:root}).trim().split(/\r?\n/).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1)];}));
if(!credential.password)throw Error('GitHub credential unavailable');
const headers={Authorization:'Bearer '+credential.password,Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'AsteraCraft-release'};
async function api(route,method='GET',body){const r=await fetch('https://api.github.com/repos/'+repo+route,{method,headers:{...headers,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});if(r.status===404)return null;const d=await r.json();if(!r.ok)throw Error('GitHub '+r.status+' '+d.message);return d;}
(async()=>{
 const sha=cp.execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8',cwd:root}).trim();
 if((await api('/commits/main')).sha!==sha)throw Error('Exact source commit has not reached GitHub main');
 const releases=await api('/releases?per_page=100');let release=releases.find(r=>r.tag_name===tag);
 if(!release)release=await api('/releases','POST',{tag_name:tag,target_commitish:sha,name:'AsteraCraft 화면·동작 수정판 - 2026-10-24',body:'전 종족 건설은 앞4단계 후100%에서 마지막 완성 원화를 표시합니다.\n\n- 방향·걷기·크기·부품 및 그림자 보정, 기존 초상화 유지\n- 건물 몸체 고정과 광원 효과, 종족별 건설음, 귤 바닥/HUD 보정\n- 근접 추격, 배양 취소, 모함별 드론 생산, 승리 및 컴퓨터 항복 승인\n- 원본3개 맵의8픽셀 이동 격자786,432칸 대조\n- Windows 실행파일에 기존 아이콘7개 해상도 삽입 확인\n\n빠른 확인 결과: 1,228개 통과. 전 프레임 수동 원화 검수는 아닙니다.\n\n수정 보고서와 실제 화면: https://github.com/'+repo+'/blob/'+sha+'/docs/FEEDBACK_FIXES_20261024.md\n\nSource commit: '+sha,draft:true,prerelease:true});
 if(release.target_commitish!==sha)throw Error('Existing preview release points to another commit');
 const names=['AsteraCraft-Windows-feedback-20261024.zip','AsteraCraft-Windows-feedback-20261024.zip.sha256'];
 const wanted=fs.readFileSync(path.join(out,names[1]),'utf8').trim().split(/\s+/)[0];
 for(const name of names){
  const file=path.join(out,name),size=fs.statSync(file).size;let asset=release.assets.find(a=>a.name===name);
  if(!asset){console.log('Uploading '+name+' '+size+' bytes');const r=await fetch(release.upload_url.split('{')[0]+'?name='+encodeURIComponent(name),{method:'POST',headers:{...headers,'Content-Type':name.endsWith('.zip')?'application/zip':'text/plain','Content-Length':String(size)},body:fs.createReadStream(file),duplex:'half'});asset=await r.json();if(!r.ok)throw Error('Upload '+r.status+' '+asset.message);}
  if(asset.size!==size||asset.state!=='uploaded'||(name.endsWith('.zip')&&asset.digest!=='sha256:'+wanted))throw Error('Uploaded asset integrity mismatch: '+name);
 }
 if(release.draft)release=await api('/releases/'+release.id,'PATCH',{draft:false,prerelease:true,make_latest:'false'});
 const verified=await api('/releases/tags/'+tag);const asset=verified.assets.find(a=>a.name===names[0]);
 if(verified.draft||!asset||asset.digest!=='sha256:'+wanted)throw Error('Published preview confirmation failed');
 const result={url:verified.html_url,asset:asset.browser_download_url,commit:sha,bytes:asset.size,sha256:wanted,quick_checks:1228,quick_failures:0,full_art_review:false};
 fs.writeFileSync(path.join(out,'github-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
