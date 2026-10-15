const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.1-20261016');
fs.mkdirSync(out,{recursive:true});
const copy=(from,rel)=>{const dest=path.join(out,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(from,dest)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck'])copy(path.join(root,'build/release-v051',name),name);
for(const name of ['node.exe','Node-LICENSE.txt','Node-VERSION.txt'])copy(path.join(root,'runtime',name),'runtime/'+name);
copy(path.join(root,'server/server.js'),'server/server.js');
copy(path.join(root,'network.example.json'),'network.example.json');
const licenses=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.4/licenses');
for(const name of fs.readdirSync(licenses))copy(path.join(licenses,name),'licenses/'+name);
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5.1 / Windows / 2026-10-16',
'',
'1. ZIP 파일을 원하는 폴더에 전부 압축 해제합니다.',
'2. AsteraCraft.exe를 실행합니다. Godot 또는 Node.js를 따로 설치할 필요가 없습니다.',
'3. AsteraCraft.pck와 runtime, server 폴더는 EXE와 함께 유지합니다.',
'4. 음성 크기는 설정의 대사 음량으로 조절합니다.',
'',
'이번 빌드는 현재 작업본의 그래픽 수정과 유닛 초상화 우선순위, 일반·스페셜 반응, 종족별 상황 안내를 포함합니다.',
'39종 유닛과 배양체 반응, 종족별 나레이션을 합쳐 음원 442개가 포함됩니다.',
'말하는 음성은 로컬 한국어 TTS에 유닛별 효과를 적용한 버전이며, 귤 유닛의 포효는 절차적 합성입니다.',
'멀티플레이의 인터넷 공개 로비는 별도 서버 운영이 필요합니다. 이번 작업은 EXE 재빌드이며 새 공개 서버를 배포하지 않았습니다.',
'',
'실행 파일: Godot 4.6 stable 공식 Windows x86_64 release template.',
'licenses 폴더에 Godot 및 폰트 라이선스가 포함되어 있습니다.',
''
].join('\r\n'));
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5.1 / Windows / 2026-10-16','',
'1. ZIP을 전부 압축 해제하고 AsteraCraft.exe를 실행하세요.',
'2. AsteraCraft.pck와 runtime, server 폴더를 EXE와 함께 유지하세요.',
'3. 일귤은 현장 도착 후 건설을 시작할 때 소모됩니다. 소모형 일꾼 한 마리로 여러 건물을 예약할 수 없습니다.',
'4. 배양체는 군체 모수 앞에 생성됩니다. 앞이 막히면 생성이 대기합니다. 생산 반복 입력은 빈 배양체를 차례로 변태시킵니다.',
'5. 그림자 접점과 앞뒤 표시, 아이콘 잘라내기, 얼굴 중심 초상화, 귤/부엉이 단일 메뉴를 수정했습니다.',
'6. 아스는 2.2초 채취 후 5를 운반합니다. 테라는 시설당 3.5초마다 8을 추출합니다.',
'7. AI는 실제 자원 거점과 이동 가능 경로를 바탕으로 확장합니다. 난이도별 반응 주기, 일꾼 목표, 진출/확장/후퇴 기준이 다릅니다.',
'8. 화면 안에서 보이는 공격은 음성 안내를 생략합니다. 미니맵 표시는 유지합니다.',
'',
'미완료 사항:',
'- 외부 TTS 사이트의 새 음성은 아직 확보하지 못했습니다. 이 빌드는 기존 로컬 TTS 302개와 합성 괴수음 140개를 사용하며 발화 속도와 응답 지연만 개선했습니다.',
'- 요청된 바위너구리 저음 남성 / 여성 감염체 나레이터 / 장엄한 부엉이 음색은 외부 녹음 교체 후 별도 청취 검수가 필요합니다.',
'- 제공된 투혼/로스트템플/파이썬 파일의 타일 및 자원 좌표 분석은 완료했으나, 게임 내 맵 지형은 아직 해당 원본으로 교체하지 않았습니다.',
'- AI 검사는 기본 생산과 확장/전투 행동 검증입니다. 사람 수준의 전략 완성도나 최종 종족 밸런스를 보장하는 평가는 아닙니다.',
'',
'자체 점검: QA_REPORT.json 참고. 외부 음성 교체용 대사/지시문: TTS-Replacement 폴더.',
'Godot 4.6 stable 정식 Windows x86_64 release template. licenses에 관련 라이선스 포함.',''
].join('\r\n'));
copy(path.join(root,'docs/external_tts_lines_v051.csv'),'TTS-Replacement/lines.csv');
copy(path.join(root,'data/external_voices_v051.json'),'TTS-Replacement/manifest.json');
copy(path.join(root,'docs/reference_maps_20261016.json'),'REFERENCE_MAPS.json');
const audit={version:'0.5.1',date:'2026-10-16',checks:{gameplay_regression:248,voice_regression:1410,voice_ui:21,feedback_ui:7,exported_pack:472,actual_release_boot_exit:0,bot_openings:9},visual_review:['three faction HUDs and building portrait closeups','single faction menu controls','measured icon crops','building-ground shadow anchor','brood foreground placement'],limitations:['External TTS replacement not completed; no external recordings imported.','SCM/SCX extracted and inspected but not yet used as runtime maps.','Nine 240-second bot openings are not a full win-rate balance evaluation.','Original attached screenshots could not be downloaded; source assets and newly rendered game captures were reviewed.'],economy:{as_per_trip:5,as_harvest_seconds:2.2,tera_per_tick:8,tera_tick_seconds:3.5},bot:JSON.parse(fs.readFileSync(path.join(root,'build/bot-v051-report.json')))};
fs.writeFileSync(path.join(out,'QA_REPORT.json'),JSON.stringify(audit,null,2));
const inventory=[];
function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())walk(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);inventory.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
walk(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.1',date:'2026-10-16',engine:'4.6.stable.official.89cea1439',runtime:'release template',files:inventory},null,2));
console.log(JSON.stringify({out,files:inventory.length,bytes:inventory.reduce((n,f)=>n+f.bytes,0)}));
