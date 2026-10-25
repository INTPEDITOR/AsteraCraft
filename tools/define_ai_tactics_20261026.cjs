const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),g=JSON.parse(fs.readFileSync(path.join(root,'data/game.json'),'utf8'));
const review=JSON.parse(fs.readFileSync(path.join(root,'docs/ai-tactics-review-20261025.json'),'utf8'));
const unlocks=[
 [[1,2,3],[4,5,10],[6,8,9,11,12,14],[7,15,16,17,20,25],[13,18,19,22,23],[21,24]],
 [[1,3,6],[4,5,22],[7,8,9,13,17,18],[2,10,11,12,14,16],[15,19,20,21,23],[24,25]],
 [[1,2,3],[5,6,25],[7,8,9,10,11,17],[4,12,13,14,16,18],[15,19,20,21,22],[23,24]]
];
const styles=[
 ['line','rush','line','mobile','siege','rush','raid','counter_air','siege','expand','siege','heavy','siege','heavy','air_raid','air_control','split','carrier','carrier','stealth','nuclear','drop','drop','drop','split_raid'],
 ['rush','expand_raid','line','control','rush','line','control','siege','counter_air','air_raid','mixed','air_control','suicide','siege','control','mobile','sustain','heavy','siege','split','forward','expand_transition','drop','drop','drop'],
 ['rush','line','rush','forward','control','heavy','rush','siege','beam','heavy','caster','caster','stealth','flank','air_stealth','siege','capital','mixed','beam','siege','drop','drop','drop','drop','expand_transition']
];
const entries=review.tactics.map(t=>{
 const n=Number(t.id.slice(1))-1,style=styles[t.race][n];
 const min_level=unlocks[t.race].findIndex(xs=>xs.includes(n+1));
 if(min_level<0)throw Error('Missing unlock '+t.id);
 const weights={};
 for(const k of t.main_kinds){const d=g.units[t.race][k];if(k>0)weights[k]=d.role==='transport'?1.5:6;}
 for(const k of t.support_kinds){const d=g.units[t.race][k];if(k>0)weights[k]=d.role==='detector'?.7:d.role==='healer_detector'?1.2:2;}
 const kinds=[...t.main_kinds,...t.support_kinds];
 const skills=g.abilities.filter(a=>a.race===t.race&&a.kinds.some(k=>kinds.includes(k))).map(a=>a.id);
 const stage=t.phase.startsWith('초반')?0:t.phase.startsWith('중반')?1:2;
 return {id:t.id,name:t.name,race:t.race,min_level,stage,min_time:stage===0?0:stage===1?100:300,style,primary:t.main_kinds.filter(k=>k>0),support:t.support_kinds.filter(k=>k>0),weights,skills,
  economy:style.startsWith('expand')?'expand':'balanced',transition:style==='expand_transition',forward:style==='forward',drop:style==='drop',split:style.startsWith('split')||style==='flank'||style==='air_stealth',
  payload:t.main_kinds.filter(k=>k>0&&!g.units[t.race][k].air),transport:style==='drop'?t.main_kinds.find(k=>g.units[t.race][k].role==='transport'):-1};
});
if(entries.length!==75||new Set(entries.map(x=>x.id)).size!==75)throw Error('Expected 75 unique plans');
const counts=[0,1,2].map(r=>unlocks[r].map((_,level)=>entries.filter(t=>t.race===r&&t.min_level<=level).length));
if(counts.some(xs=>xs.join(',')!=='3,6,12,18,23,25'))throw Error('Non-cumulative difficulty');
fs.writeFileSync(path.join(root,'data/ai_tactics.json'),JSON.stringify({version:1,approved:true,counts,plans:entries},null,2)+'\n');
if(!review.status.startsWith('implemented')){
 review.status='approved_for_implementation';review.approval='User approved all 25 per faction on 2026-10-26; runtime verification pending.';
}
fs.writeFileSync(path.join(root,'docs/ai-tactics-review-20261025.json'),JSON.stringify(review,null,2)+'\n');
console.log(JSON.stringify({plans:entries.length,counts}));
