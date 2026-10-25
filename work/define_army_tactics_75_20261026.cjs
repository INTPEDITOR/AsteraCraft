const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const file=path.join(root,'docs/ai-tactics-review-20261025.json');
const previous=JSON.parse(fs.readFileSync(file,'utf8'));
if(previous.approval)throw Error('The tactics were approved by the user. Preserve the approved catalog; do not regenerate it as a pending proposal.');
const gameBytes=fs.readFileSync(path.join(root,'data/game.json'));
const coreBytes=fs.readFileSync(path.join(root,'scripts/core.gd'));
const game=JSON.parse(gameBytes);
// One row is an army plan, not an individual spell or micro response.
// name, primary kinds, support kinds, operating plan, phase
const rows=[
 [
  ['전열사수 물량전',[1],[4],'전열사수를 꾸준히 충원해 큰 보병대를 만들고 의무병 지원으로 전선을 밀어붙인다.','초반'],
  ['돌격병 빠른 돌파',[2],[1,4],'돌격병을 먼저 모아 적의 원거리 병력에 붙는 근접 중심 초반 공격을 건다.','초반'],
  ['방패보병 중장 보병전',[3],[1,4],'방패보병 비중을 높여 전열을 오래 유지하고 뒤의 사수들이 안정적으로 사격한다.','초반~중반'],
  ['혼합 보병 기동전',[1,2],[3,4],'사수·돌격병 혼합군을 중심으로 전장을 옮겨 다니며 적 지상군과 멀티를 압박한다.','중반'],
  ['보병·전차 연합',[1,5],[4,8],'보병이 전차를 보호하고 전차가 먼 거리의 방어선과 밀집 지상군을 무너뜨린다.','중반'],
  ['돌격병·화염차 돌파군',[2,13],[6],'기동 근접군과 화염차를 함께 밀어 넣어 적의 보병 전열과 채취선을 압박한다.','중반'],
  ['화염차·차륜차 기동군',[13,6],[8],'빠른 기계 부대로 적 주력과 정면 소모전을 피하며 외곽 멀티와 충원로를 번갈아 공격한다.','중반'],
  ['차륜차 중심 대공군',[6],[5,13,8],'정찰한 적 공중군에 맞춰 차륜차를 주력으로 생산하고 전차·화염차가 지상 공격을 맡는다.','중반'],
  ['전차 장기 공성',[5],[6,3,8],'전차를 충분히 모아 적진 앞에 공성선을 만들고 거점을 차례로 압박한다.','중반~후반'],
  ['전차 방어 후 확장',[5],[1,0],'소수 전차와 보병으로 입구를 지키며 멀티를 먼저 확보한 뒤 기계 병력을 늘려 진출한다.','초반→후반'],
  ['방패·전차 전선 유지',[3,5],[4,6],'방패보병이 접근하는 적을 막고 전차가 후방에서 사격하는 느리지만 단단한 지상군을 운용한다.','중반'],
  ['이동요새 주력군',[12],[6,0],'이동요새 여러 기를 중심으로 큰 전선을 형성하고 차륜차와 정비공이 전투 지속을 지원한다.','후반'],
  ['요새·전차 중공성군',[12,5],[6,0],'요새로 전차를 지키며 적의 두꺼운 방어 거점을 장거리 포격과 중화력으로 해체한다.','후반'],
  ['요새·보병 혼합군',[12,1],[3,4],'요새가 전선을 잡고 대규모 보병이 빈 공간을 채워 여러 지상·공중 표적에 대응한다.','후반'],
  ['강습폭격기 주력 공세',[10],[9,8],'폭격기 편대를 주력으로 키워 지상군과 채취선을 공격하고 요격기가 호위한다.','중반~후반'],
  ['제공권 확보 후 폭격',[9],[10,6,8],'요격기를 먼저 확보해 적 공중군과 수송을 억제한 뒤 폭격기로 지상 압박을 이어간다.','중반'],
  ['전차·폭격기 연합 공세',[5,10],[9,8],'전차가 정면을 포격하는 동안 폭격기가 지형을 넘어 측면의 지상 표적을 공격한다.','후반'],
  ['강철둥지 모함 함대',[14],[9,8],'실제 비용으로 요격 드론을 충원한 모함을 모으고 요격기 호위 아래 제공권과 전장을 장악한다.','후반'],
  ['모함·요새 복합군',[14,12],[9,0],'지상의 요새와 공중 모함이 함께 전진해 한쪽 공격 유형만으로 막기 어려운 주력을 만든다.','후반'],
  ['그림자 정찰병 사격군',[7],[1,4,8],'정찰병의 은신·사격을 주력으로 삼아 고가 표적을 압박하고 보병이 정면과 퇴로를 보호한다.','중반~후반'],
  ['핵 지원 공성전',[7,5],[1,8],'핵을 실제 생산한 뒤 전차 공성으로 적을 묶고 핵 유도로 밀집 거점의 철수와 방어 재배치를 유도한다.','후반'],
  ['보병 공중기동전',[11,1,2],[4],'장갑수송정으로 보병 주력을 운반해 지상 방어선을 우회하고 취약한 본진·멀티를 공격한다.','중반'],
  ['전차 공중기동전',[11,5],[6,8],'수송정으로 전차를 합법적인 고지대와 측면에 옮겨 적 거점을 여러 사격 방향에서 압박한다.','중반~후반'],
  ['화염차 수송 기습',[11,13],[9],'화염차를 수송해 적 채취선 뒤에 투입하고 지상 수비군이 복귀하기 전에 회수한다.','중반'],
  ['지상·공중 분산 견제',[13,10],[6,8],'화염차와 폭격기를 별도 부대로 굴려 서로 다른 멀티를 압박하며 적 주력을 분산시킨다.','중반~후반']
 ],
 [
  ['껍질발톱 초반 물량',[1],[],'초반 발톱 생산에 집중해 적이 방어와 고급 기술을 갖추기 전에 한 무리로 공격한다.','초반'],
  ['발톱 기동 확장전',[1],[7,9],'확장을 늘리며 발톱 부대로 외곽을 넓게 압박하고 가시꽃·모즙체가 거점을 지킨다.','초반→중반'],
  ['과즙분사체 물량군',[2],[1],'분사체를 주력으로 꾸준히 충원하고 발톱이 앞에서 접근하는 지상군을 견제한다.','초반~중반'],
  ['덩굴포식자 제압군',[5],[1,9],'덩굴포식자를 주력으로 적의 접근과 퇴각을 늦추며 모즙체 지원 아래 지상 전선을 유지한다.','중반'],
  ['거수·발톱 돌파군',[3,1],[9],'거수가 공격을 버티는 동안 다수의 발톱이 양옆을 파고드는 근접 중심 대군을 운용한다.','중반'],
  ['거수·분사체 정규군',[3,2],[7,9],'거수 전열과 분사체 화력을 균형 있게 모아 지상 정면전을 주도하고 가시꽃으로 대공을 보완한다.','중반'],
  ['거수·덩굴 압박군',[3,5],[9],'거수의 근접 화력과 덩굴포식자의 둔화를 결합해 적 지상 주력을 붙잡고 전투를 지속한다.','중반'],
  ['씨앗박격체 공성군',[6],[3,7,9],'박격체를 주력으로 모아 적의 방어 거점과 밀집 지상군을 포격하고 거수·가시꽃이 보호한다.','중반~후반'],
  ['가시꽃 중심 대공군',[7],[2,5,9],'가시꽃 비중을 크게 높여 적 공중 주력의 진입을 억제하고 분사체·덩굴포식자가 지상 부대를 막는다.','중반'],
  ['귤박쥐 공중 기동전',[10],[1],'귤박쥐를 주력으로 키워 고립 부대와 채취선을 연속 공격하고 발톱으로 지상 압박을 보탠다.','중반'],
  ['귤박쥐·분사체 연합군',[10,2],[9],'분사체 지상군과 귤박쥐 공중군이 함께 움직이며 적 지상·공중 조합을 상대한다.','중반'],
  ['귤박쥐·가시꽃 제공전',[10,7],[3],'가시꽃 진지를 바탕으로 귤박쥐가 공중 교전에 참여하고 거수가 지상 침투를 막는다.','중반'],
  ['과숙폭탄 돌파군',[4],[1,3],'발톱·거수로 전선을 만들고 폭탄을 주력 타격 수단으로 사용해 적 지상 밀집군을 무너뜨린다.','중반'],
  ['폭탄·박격체 범위군',[4,6],[3,7],'박격체 포격으로 적이 자리를 옮기게 만들고 접근하는 지상군을 폭탄과 거수로 맞받는다.','중반~후반'],
  ['접목충·거수 통제군',[8,3],[2,9],'거수가 전선을 버티는 동안 접목충이 신경 교란·정신 조종으로 적 고가 병력의 전력을 줄인다.','후반'],
  ['접목충·귤박쥐 기동군',[8,10],[1],'빠른 접목충 지상 부대와 귤박쥐가 고립된 고가 표적을 압박하고 정면 소모전은 피한다.','후반'],
  ['모즙체 지원 장기전',[9,2],[3,5,1],'모즙체 비중을 높여 치유·개화로 병력을 보존하고 필요할 때 생명환원을 사용하며 압박을 이어간다.','중반~후반'],
  ['대과수·거수 중군',[12,3],[7,9],'대과수와 거수를 주력으로 모아 큰 지상 전선을 만들고 가시꽃·모즙체가 대공과 회복을 담당한다.','후반'],
  ['대과수·박격체 공성',[12,6],[7,9],'대과수를 전선의 중심으로 두고 박격체가 뒤에서 적 건물과 방어선을 포격한다.','후반'],
  ['대과수·귤박쥐 복합군',[12,10],[7,9],'대과수가 지상을 장악하고 귤박쥐가 지형을 넘어 측면과 후방을 공격한다.','후반'],
  ['뿌리 전진 거점전',[5,6],[0,3,9],'일귤이 뿌리중계체·방어 거점을 실제 건설하며 덩굴·박격체 주력이 거점 사이를 전진한다.','중반~후반'],
  ['방어 확장 후 거대군',[2,7],[9,3,12],'분사체·가시꽃과 방어 건물로 멀티를 확보하고 경제가 갖춰지면 거수·대과수 중심으로 전환한다.','초반→후반'],
  ['분사체·덩굴 수송전',[11,2,5],[10],'포낭비행체로 원거리 지상 병력을 수송해 적의 측면과 멀티에 별도 전선을 만든다.','중반'],
  ['후피거수 강습전',[11,3],[2,10],'거수를 실은 포낭비행체로 방어선을 넘어 내려놓고 분사체·귤박쥐가 교두보를 지원한다.','중반~후반'],
  ['과숙폭탄 수송전',[11,4],[10,1],'포낭비행체에 폭탄을 싣고 본대와 다른 방향의 채취선·밀집 지상 거점을 기습한다.','중반~후반']
 ],
 [
  ['서약수호자 초기 공세',[1],[],'초반 수호자 생산에 집중해 적이 원거리 화력과 고급 기술을 갖추기 전에 압박한다.','초반'],
  ['성문궁수 주력군',[2],[1],'궁수 비중을 높여 지상·공중 사격을 맡기고 소수 수호자가 앞을 막는다.','초반~중반'],
  ['수호자·사제 돌파군',[1],[4,3],'수호자를 주력으로 모아 사제의 보호·치유와 집행관 지원 아래 지상 방어선을 돌파한다.','중반'],
  ['전진 거점 압박',[2,3],[0,4],'축조자가 규율탑과 방어탑을 실제 건설하고 궁수·집행관 주력이 적 멀티 앞에 거점을 만든다.','초반~중반'],
  ['집행관·궁수 제압군',[3,2],[4],'집행관 비중을 높여 적의 움직임을 제한하고 궁수 집단이 안전하게 사격한다.','중반'],
  ['고대석익병 중군',[7],[2,4],'석익병을 주력으로 정면 전선을 형성하고 궁수와 사제가 화력·지속력을 보완한다.','중반'],
  ['석익병·수호자 돌파군',[7,1],[3,4],'튼튼한 석익병과 수호자를 함께 밀어 넣어 적의 원거리 지상군에 가까이 붙는 전투를 건다.','중반'],
  ['궤도창 장거리 공성',[8],[7,2,6],'궤도창을 충분히 모으고 석익병 호위·감시자 시야 아래 적 거점을 먼 거리에서 해체한다.','중반~후반'],
  ['성좌추격기 주력군',[13],[1,2,4],'추격기를 주력으로 키워 수호자가 붙잡은 지상 표적에 지속 빔 화력을 집중한다.','중반~후반'],
  ['추격기·석익병 중장군',[13,7],[4,6],'석익병의 전열과 추격기의 지속 화력을 결합해 적의 고체력 지상 주력을 상대한다.','후반'],
  ['천문심판관 지원군',[5],[1,2,4],'심판관을 충분히 확보해 수호자·궁수 본대가 싸우는 동안 지연 범위 공격으로 적 밀집군을 압박한다.','중반~후반'],
  ['심판관·석익병 범위군',[5,7],[3,6],'석익병의 충격파와 심판관의 범위 공격을 중심으로 밀집한 지상 부대를 상대한다.','후반'],
  ['황혼잠행자 은신 주력',[10],[6,3],'잠행자를 주력으로 모아 정찰된 탐지 공백과 고립 표적을 공략하고 감시자·집행관이 지원한다.','중반~후반'],
  ['잠행자·궁수 혼합군',[10,2],[4,6],'궁수가 정면을 잡는 동안 잠행자가 측면에서 접근해 적 원거리 주력과 지원 병력을 압박한다.','후반'],
  ['월익·잠행자 연합',[9,10],[6],'월익추적자가 적 공중군·공중 탐지기를 상대하고 잠행자가 지상 거점을 공격한다.','중반~후반'],
  ['월익·궤도창 제공 공성',[9,8],[6,1],'월익추적자가 공중 위협을 차단하고 감시자가 시야를 제공하는 동안 궤도창이 지상을 포격한다.','중반~후반'],
  ['대심판선 함대',[12],[9,6],'대심판선을 주력으로 모아 월익 호위 아래 적 지상·공중 거점을 함께 압박한다.','후반'],
  ['대심판선·석익병 연합',[12,7],[4,6],'공중 대심판선과 지상 석익병이 전선을 함께 형성하고 사제가 지상군을 지원한다.','후반'],
  ['대심판선·추격기 화력군',[12,13],[9,6],'대심판선과 추격기의 화력을 적 고체력 지상군에 집중하고 월익추적자가 대공 호위를 맡는다.','후반'],
  ['대심판선·궤도창 중공성',[12,8],[9,1,6],'함대와 장거리 포격대를 함께 모아 적의 대규모 방어선을 여러 공격 거리에서 압박한다.','후반'],
  ['황혼잠행자 수송전',[11,10],[9],'회랑지기로 잠행자 주력을 적 후방에 운반해 지상 방어선과 탐지 배치를 우회한다.','중반'],
  ['궤도창 수송 포격전',[11,8],[9,6],'회랑지기로 궤도창을 측면에 옮겨 포격하고 적이 접근하면 회수해 다른 거점을 노린다.','중반~후반'],
  ['고대석익병 강습전',[11,7],[4,9],'회랑지기로 석익병을 수송해 적 후방에 단단한 교두보를 만들고 사제·월익이 지원한다.','중반~후반'],
  ['천문심판관 수송전',[11,5],[9,6],'회랑지기로 심판관을 밀집한 채취선·부대 근처에 내려 범위 공격한 뒤 회수한다.','중반~후반'],
  ['방어 확장 후 함대전환',[2,12],[9,6],'궁수와 동력 방어탑으로 멀티를 지키며 자원을 확보한 뒤 대심판선 함대로 주력을 전환한다.','초반→후반']
 ]
];
if(rows.length!==3||rows.some(x=>x.length!==25))throw Error('Need exactly 25 army plans per faction');
const prefix=['N','E','A'];
const tactics=[];
for(let race=0;race<3;race++)for(let i=0;i<25;i++){
 const [name,primary,support,action,phase]=rows[race][i];
 const kinds=[...primary,...support];
 if(new Set(kinds).size!==kinds.length||kinds.some(k=>!game.units[race][k]))throw Error('Invalid or duplicate unit '+race+':'+name);
 if(!primary.some(k=>game.units[race][k].damage>0||game.units[race][k].role==='carrier'))throw Error('Army needs real damage '+name);
 const names=ks=>ks.map(k=>game.units[race][k].name);
 tactics.push({id:prefix[race]+(i+1),race,name,phase,main_kinds:primary,support_kinds:support,main_units:names(primary),support_units:names(support),units:names(kinds).join('·'),action,
  trigger:'실제 생산·연구·자원·인구 조건을 충족하고 정찰 정보와 지형에 이 조합의 목적이 맞을 때',
  abort:'정찰한 적 조합이 주력의 약점을 찌르거나 본진 방어·생존·퇴로가 위태로우면 철수/재집결/다른 주력으로 전환',
  implementation_status:'proposal_only_awaiting_user_review'});
}
const result={
 status:'awaiting_user_review_not_implemented',quantity_per_race:25,total:75,
 scope:'Three factions, 25 army-level strategic plans each. Original game design informed by the earlier official StarCraft references, not a claim that all 75 are named StarCraft strategies.',
 design_level:'Primary army composition, support units, macro objective and operating method. Individual abilities are subordinate actions, not additional strategies.',
 rules:[...previous.rules,
  'Final user correction: 25 large army/strategy plans for each faction, 75 total. Earlier 40/60 counts and micro-only additions are superseded.',
  'Production weights and build orders belong to each army plan; no free units, instant tech, forced enemy reactions or stat bonuses.',
  'Pure ground/air-specialized armies must transition or bring support when scouting reveals counters. Nova fighters and Araowl moon fighters cannot attack ground.',
  'Skills including smoke, bind, cleanse, scatter and repair belong inside these army plans; do not count them as separate large strategies.'
 ],
 difficulties:previous.difficulties,
 tactics,
 sources:previous.sources,
 current_game_limits:{
  nova:'Fighter air-only; bomber ground-only; carrier drones must be paid for; nukes damage own army; no mines or flying buildings.',
  egyul:'Bat attacks ground/air; pod is transport only; Mojeup is a ground detector; roots spread across legal ground; no burrow/Lurker/DarkSwarm/Nydus.',
  araowl:'Moon fighter air-only; chaser ground-only; capital is a direct-fire ship, not a carrier; no Recall/Stasis/warp/Yamato; judgment is delayed area damage, not storm damage over time.',
  transports:'Passenger population sum 8; legal actual ground for unload; no landing on impassable cliff faces.'
 }
};
result.rules=[...new Set(result.rules)];
for(let race=0;race<3;race++){
 const compositions=new Set();
 for(const t of tactics.filter(t=>t.race===race)){
  const key=[...t.main_kinds,...t.support_kinds].sort((a,b)=>a-b).join(',');
  if(compositions.has(key))throw Error('Duplicate entire army '+t.id);
  compositions.add(key);
 }
}
const folder=path.join(root,'build/ai-tactics-review-20261026');fs.mkdirSync(folder,{recursive:true});
const archive=path.join(folder,'previous-'+previous.tactics.length+'.json');
if(!fs.existsSync(archive))fs.writeFileSync(archive,JSON.stringify(previous,null,2)+'\n');
fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n');
if(!fs.readFileSync(path.join(root,'data/game.json')).equals(gameBytes)||!fs.readFileSync(path.join(root,'scripts/core.gd')).equals(coreBytes))throw Error('Game runtime must not change');
const checks={passed:true,total:tactics.length,counts:[0,1,2].map(r=>tactics.filter(x=>x.race===r).length),unique_ids:new Set(tactics.map(x=>x.id)).size,all_kinds_verified_against_game_json:true,runtime_unchanged:true,ai_not_implemented:true,game_sha256:crypto.createHash('sha256').update(gameBytes).digest('hex')};
fs.writeFileSync(path.join(folder,'inventory-checks.json'),JSON.stringify(checks,null,2)+'\n');
console.log(JSON.stringify(checks));
