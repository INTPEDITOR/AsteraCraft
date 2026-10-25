const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const read=f=>JSON.parse(fs.readFileSync(path.join(root,f),'utf8'));
const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex');
const log=f=>{const b=fs.readFileSync(path.join(root,f));return b.subarray(0,2).equals(Buffer.from([255,254]))?b.subarray(2).toString('utf16le'):b.toString('utf8');};
const suites=[
 ['exact_worker_centerline','build/worker-centerline-20261026/result.json','build/worker-centerline-console.txt'],
 ['geometry_equivalence_before_after_query_optimization','build/worker-centerline-20261026/equivalence.json','build/worker-centerline-equivalence-console.txt'],
 ['worker_permissions_and_native_maps','build/worker-passages-20261025/result.json','build/worker-centerline-passages-final-console.txt'],
 ['worker_mining_and_construction','build/worker-passages-20261025/jobs.json','build/worker-centerline-jobs-console.txt'],
 ['cliff_guards','build/cliff-fix-20261025/result.json','build/worker-centerline-cliffs-console.txt'],
 ['movement_continuity','build/move-continuity-20261025/worker-centerline/result.json','build/worker-centerline-movement-console.txt'],
 ['native_group_movement','build/group-move-continuity-20261025/worker-centerline/result.json','build/worker-centerline-group-console.txt'],
 ['all_75_real_primary_production','build/ai-tactics-20261026/plans.json','build/ai-tactics-plans-final-console.txt'],
 ['all_10_drop_missions_nuclear_and_skills','build/ai-tactics-20261026/missions.json','build/ai-tactics-missions-final-console.txt'],
 ['local_defense_scouting_two_leg_cohorts','build/ai-tactics-20261026/coordination.json','build/ai-tactics-coordination-final-console.txt'],
 ['slow_member_forward_assembly','build/ai-staging-20261025/result.json','build/ai-tactics-forward-final-console.txt'],
 ['three_race_three_map_staging','build/ai-staging-20261025/source-walk.json','build/ai-tactics-source-staging-final-console.txt'],
 ['actual_passive_research','build/passives-20261024/bot-result.json','build/ai-tactics-passives-final-console.txt'],
 ['six_difficulties_90_defense_scenarios','build/difficulty-progression-20261025/response-0.json','build/ai-tactics-difficulty-final-console.txt'],
 ['same_race_and_unique_colors','build/single-mirror-20261025/result.json','build/ai-tactics-mirror-final-console.txt'],
];
const results=suites.map(([name,file,consoleFile])=>{
 const value=read(file);assert.equal(value.passed,true,name);assert.equal(value.failures.length,0,name);
 assert(!/SCRIPT ERROR|Parse Error|Invalid call|Assertion failed|(?:^|\n)ERROR:/.test(log(consoleFile)),consoleFile);
 return {name,file,console:consoleFile,checks:value.checks??null,cases:Array.isArray(value.cases)?value.cases.length:value.cases??null,passed:true,sha256:hash(file)};
});
const botLog=log('build/ai-tactics-bot-final-console.txt');
assert(botLog.includes('"checks":140')&&botLog.includes('"failures":[]'),'Bot regression 140 checks');
assert(!/SCRIPT ERROR|Parse Error|Invalid call/.test(botLog));
results.push({name:'bot_economy_production_power_supply',checks:140,passed:true,console:'build/ai-tactics-bot-final-console.txt'});
const centerline=read(suites[0][1]);
assert.equal(centerline.cases.length,39);assert(centerline.cases.every(c=>c.arrived&&c.samples>0&&c.max_error_tiles<=.002));
const tactics=read('data/ai_tactics.json');assert.equal(tactics.approved,true);assert.equal(tactics.plans.length,75);
assert.equal(new Set(tactics.plans.map(p=>p.id)).size,75);
for(let r=0;r<3;r++)assert.deepEqual([0,1,2,3,4,5].map(level=>tactics.plans.filter(p=>p.race===r&&p.min_level<=level).length),[3,6,12,18,23,25]);
const game=read('data/game.json');
const matches=[];
for(let race=0;race<3;race++)for(const swap of [false,true]){
 const file=`build/ai-tactics-20261026/match-${race}-739${swap?'-swap':''}.json`;
 const m=read(file);assert(m.players[0].first_attack>0,`Hell must actually send an attack: ${file}`);
 const armyValue=m.final_assembly.map(a=>a.units.reduce((sum,u)=>{const d=game.units[race][u.kind];return sum+(d.as??0)+(d.tera??0)*1.5;},0));
 matches.push({file,race,swapped_spawns:swap,seconds:m.seconds,ended:m.ended,winners:m.winners,players:m.players,remaining_army_resource_value:armyValue,p95_step_ms:m.p95_step_ms,max_step_ms:m.max_step_ms,scope:m.scope});
}
const sourceFiles=['data/ai_tactics.json','data/game.json','scripts/bot_ai.gd','scripts/bot_tactics.gd','scripts/bot_missions.gd','scripts/bot_skills.gd','scripts/world_map.gd','scripts/core.gd','scripts/menu_pages.gd'];
const solo=read('build/ai-tactics-20261026/match-0-739-solo.json');
const before=read('build/ai-tactics-20261026/match-0-739-solo-before-query-optimization.json');
const report={
 status:'implemented_and_locally_verified_not_released',generated_at:new Date().toISOString(),
 runtime_plans:75,plans_per_race:25,repertoires:[3,6,12,18,23,25],
 source_sha256:Object.fromEntries(sourceFiles.map(f=>[f,hash(f)])),
 passed_suites:results,checks:results.reduce((n,s)=>n+(s.checks??0),0),
 worker_centerline:{physical_walk_cases:39,contact_samples:centerline.cases.reduce((n,c)=>n+c.samples,0),maximum_center_deviation_tiles:Math.max(...centerline.cases.map(c=>c.max_error_tiles)),scope:'Own ground workers only, on the real shared footprint edge. Foreign and allied-other-owner buildings, terrain and resources remain blocked.'},
 hell:{decision_interval_seconds:.25,opening_main_cohort_minimum:6,all_25_plans:true,resource_or_unit_stat_cheats:false,scouting_only:true,mirror_matches:matches,mirror_run_note:'Six mirrors preceded the final geometry-equivalent passage-query optimization. The following solo run and 7020 direct geometry comparisons validate that optimization.',solo_performance:{file:'build/ai-tactics-20261026/match-0-739-solo.json',p95_step_ms:solo.p95_step_ms,max_step_ms:solo.max_step_ms,worst_step:solo.worst_step,before:{file:'build/ai-tactics-20261026/match-0-739-solo-before-query-optimization.json',p95_step_ms:before.p95_step_ms,max_step_ms:before.max_step_ms}}},
 limits:[
  'Every plan is checked for real paid primary production at mature tech. This is not 75 complete games from the normal starting economy.',
  'All 10 transport plans perform physical load, flight, legal unload, combat, extraction and return. Nuclear, conversion and delayed area spells use real gameplay commands.',
  'Six normal-economy mirrors compare Hell against Very Hard, swapping native map starting positions. Small fixed-seed samples are not a general win-rate or human difficulty guarantee.',
  'Headless accelerated runs may overlap. Timings are diagnostics, not a rendered-frame-rate claim; remaining worst-step spikes are recorded.',
  'No Windows build, updater integration, GitHub publication or change to the last public release was performed for this source update.'
 ]};
const out='docs/verification_ai_tactics_20261026';fs.mkdirSync(path.join(root,out),{recursive:true});
fs.writeFileSync(path.join(root,out,'checks.json'),JSON.stringify(report,null,2)+'\n');
const review=read('docs/ai-tactics-review-20261025.json');
review.status=report.status;review.verification=out+'/checks.json';
review.approval='User approved all 25 army plans per faction on 2026-10-26; implemented and locally verified. No public release requested for this update.';
for(const p of review.tactics)p.implementation_status=report.status;
fs.writeFileSync(path.join(root,'docs/ai-tactics-review-20261025.json'),JSON.stringify(review,null,2)+'\n');
const advantage=matches.filter(m=>m.remaining_army_resource_value[0]>m.remaining_army_resource_value[1]).length;
const names=['노바너','이귤','아라아울'];
const lines=[
 '# 전술75개·헬 난이도·건물 공유 경계 통행 소스 검증',
 '',
 '사용자가 승인한 종족별25개 전술을 실제 자체AI에 연결했다. 소스 검증 결과이며 새 Windows 배포나 공개 업데이트는 수행하지 않았다.',
 '',
 '## 구현',
 '',
 '- 난이도별 전술 폭은 종족마다3 → 6 → 12 → 18 → 23 → 25개로 누적된다. 헬의 판단 주기는0.25초다.',
 '- 실제 정찰과25~150초의 제한된 기억으로 병력 조합을 선택한다. 안개 속 적 위치·자원 특혜·추가 능력치는 사용하지 않는다.',
 '- 전술마다 실제 주력/지원 생산 비중, 생산 건물과 선행 기술, 보급·테라·연구 예산을 사용한다. 가격과 생산 시간을 건너뛰지 않는다.',
 '- 본진에서 한 부대를 만든 뒤 적 앞 집결점으로 이동하고, 느린 병력을 기다린 후 함께 진입한다. 출발 후 손실이 생기면 충분한 생존 병력은15초 기다린 뒤 함께 진입하고, 부족한 잔여 병력은 돌아와 다시 모인다. 신병을 하나씩 전선에 보내지 않는다.',
 '- 한 기의 정찰 유닛에는 가까운 소규모 방어대만 대응하고, 실제 본진 공습·공성 위협에는 주력이 복귀한다. 같은 공격 명령을 반복해 기존 이동 경로를 지우지 않는다.',
 '- 수송은8인구 적재·실제 비행·합법 지상 하차·공격·회수·귀환을 거친다. 핵은 실제 연구/탄두를 사용하며 자기 병력을 대피시키고, 다른 소유자의 아군은 임의로 움직이지 않는다.',
 '- 이동식 공성, 공중 우회, 뿌리/규율탑 전진 거점, 은신·상태 이상·범위 기술·치료/수리·연구 사용을 기존 게임 명령에 연결했다.',
 '',
 '## 건물 사이 통행',
 '',
 '자기 지상 일꾼의 접촉 중심은 두 자기 건물의 실제 공유 경계선에 맞춰진다. 건물 내부의 평행 통행로는 허용하지 않는다. 다른 소유자/동맹의 다른 소유자 건물, 일반 병력, 자원·지형 차단 규칙도 검사했다.',
 '',
 `세 종족의 가로·세로·양방향·진입 오프셋·교차점39가지 실제 이동, 접촉${report.worker_centerline.contact_samples}좌표에서 중앙 최대 이탈은${report.worker_centerline.maximum_center_deviation_tiles}칸이었다. 채취·건설 이동, 원본3맵 통행, 절벽과 단체 이동 회귀도 통과했다.`,
 '',
 '## 검증 범위',
 '',
 `기능 검사${results.length}묶음/${report.checks}조건 통과. 많은 수의 조건은 이동 중 매 틱의 몸체 충돌 확인이며 독립 경기 수와 같지 않다.`,
 '',
 '- 전술75개: 선행 기술이 갖춰진 상태에서 실제 주력 생산과 자원/인구 지불 검사.75개 전술을 모두 정상 시작 자원으로 끝까지 경기한 검사는 아니다.',
 '- 수송 전술10개: 적재 → 비행 → 하차 → 전투 → 회수 → 귀환 전체를 실행. 실제 핵 피해·아군 대피·정신 조종·지연 범위 기술도 별도 검사했다.',
 '- 마지막 통행 질의 최적화는 기존 전체 맵 누적표 방식과7020좌표에서 결과가 같았다. 이후 통행39상황/소유권·원본맵860검사/작업12검사와 단독 경기를 다시 실행했다. 아래6경기는 이 판정 동일 최적화 직전의 비교 기록이다.',
 '- 헬 대 매우어려움: 원본 맵과 기본 시작 자원으로 세 종족의 출발 위치를 바꿔6경기를600초씩 실행했다. 아래는 종료 시점의 병력 자원 가치이며 최종 승패/승률을 뜻하지 않는다.',
 '',
 '| 종족 | 시작 위치 교환 | 헬 첫 주력 진입(초) | 종료 병력 가치 헬 / 매우어려움 |',
 '|---|---|---:|---:|',
 ...matches.map(m=>`| ${names[m.race]} | ${m.swapped_spawns?'교환':'기본'} | ${m.players[0].first_attack.toFixed(1)} | ${m.remaining_army_resource_value.map(v=>v.toFixed(1)).join(' / ')} |`),
 '',
 `병력 자원 가치가 높은 경우는 헬이${advantage}/6경기다. 작은 고정 조건 표본이므로 모든 종족·상성·인간 상대의 최종 난이도나 승률을 보증하지 않는다.`,
 '',
 '## 성능과 배포 경계',
 '',
 '서로 먼 건물 공유 경계는 이음새별 작은 영역만 갱신한다. 또한 소유자별 맵 전체262144셀의 누적표 재생성을 없애고 일꾼 몸체가 닿는 셀만 같은 규칙으로 검사한다. 통행 가능한 지형이나 몸체 크기를 바꾸지 않았다.',
 '',
 `단독 헤드리스 경기의 시뮬레이션 단계95백분위는${before.p95_step_ms.toFixed(3)}→${solo.p95_step_ms.toFixed(3)}ms, 최대는${before.max_step_ms.toFixed(3)}→${solo.max_step_ms.toFixed(3)}ms였다. 병렬 가속 검사와 실제 화면 프레임률은 구분한다. 남은 최대 지연과 단계별 원인은 checks.json에 기록하며 지연이 전부 없어졌다고 보고하지 않는다.`,
 '',
 '기존 공개 배포는0.6.5/feedback11이며 이번 변경의 새 EXE/PCK/ZIP·업데이터·GitHub 게시 검사는 하지 않았다.',
 '',
 '정확한 결과·검사 파일·소스 SHA-256은 [checks.json](verification_ai_tactics_20261026/checks.json)에 있다.',
 ''
];
fs.writeFileSync(path.join(root,'docs/AI_TACTICS_IMPLEMENTED_20261026.md'),lines.join('\n'));
console.log(JSON.stringify({passed:true,suites:results.length,checks:report.checks,plans:75,mirrors:matches.length,worker_cases:39,center_deviation:report.worker_centerline.maximum_center_deviation_tiles}));
