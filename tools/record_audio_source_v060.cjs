const fs=require('fs'),path=require('path');
const [service,id,source,project]=process.argv.slice(2),root=path.resolve(__dirname,'..');
if(!id||!source||!['eleven','varco'].includes(service))throw Error('Usage: eleven|varco id source [project]');
const file=path.join(root,'data',service==='eleven'?'elevenlabs_voices_v060.json':'varco_sounds_v060.json'),data=JSON.parse(fs.readFileSync(file));
if(service==='eleven'){
 const group=data.generation_groups.find(x=>x.id===id),bank=data.banks.find(x=>x.id===id||id==='r1_ann_queen'&&x.id==='r1_ann');
 if(!group&&!bank)throw Error('Unknown bank '+id);
 const rec={id,banks:group?group.banks:[bank.id],voice:group?group.voice:bank.voice,source};
 data.recordings=data.recordings.filter(x=>x.id!==id);data.recordings.push(rec);
}else{
 let rec=data.requests.find(x=>x.id===id);
 if(!rec){rec={id,credits:50,account_batch:data.banks.find(b=>b.id===id)?.account_batch||1};data.requests.push(rec);}
 if(source==='pending'){rec.status='generated_pending_download';rec.project=project;}
 else{
  if(!fs.existsSync(source))throw Error('Missing source '+source);
  rec.source=source;rec.file='build/varco-v060/'+id+'.wav';
  fs.copyFileSync(source,path.join(root,rec.file));rec.status='downloaded';
  if(project)rec.project=project;
 }
 if(data.requests.reduce((n,r)=>n+r.credits,0)>data.budget)throw Error('Budget exceeded');
}
fs.writeFileSync(file,JSON.stringify(data,null,2));console.log(service,id,'recorded');
