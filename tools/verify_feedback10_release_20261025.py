from pathlib import Path
import json,hashlib,subprocess,sys,shutil
root=Path(__file__).resolve().parents[1];out=root/'build/feedback10_20261025';qa=root/'docs/verification_feedback10_20261025';qa.mkdir(parents=True,exist_ok=True)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
checks={}
for name,file in {
 'pack':out/'pack-result.json','windows-startup':out/'exe-smoke.json','native-visual':out/'native-visual-result.json','archive':out/'package-result.json',
 'update-install':root/'build/updater-feedback10-e2e-20261025/result.json','source-regression':root/'build/feedback10-source/result.json',
}.items():
 d=read(file);assert d['passed'],(name,d);checks[name]=d;shutil.copy2(file,qa/(name+'.json'))
assert len(checks['pack']['runs'])==14
assert checks['update-install']['tag']=='feedback10-20261025' and checks['update-install']['checks']==11
assert read(root/'data/update_channel.json')['tag']=='feedback10-20261025'
assert read(root/'data/game.json')['version']=='0.6.4'
results=out/'test-results'
before=read(root/'docs/verification_cliff_fix_20261025/formations-before.json')
after=read(results/'group-move-continuity-20261025/feedback10/result.json')
assert before['cases']==after['cases'],'Existing formation movement changed'
response=read(results/'difficulty-progression-20261025/response-0.json');assert response['passed'] and len(response['records'])==18
openings=[read(results/f'difficulty-progression-20261025/opening-{i}.json') for i in range(3)]
assert all(o['passed'] and len(o['records'])==6 for o in openings)
for name,data in [('response',response),*[(f'opening{i}',d) for i,d in enumerate(openings)]]:
 (qa/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tera=read(results/'tera-source-comparison-20261025/result.json');assert tera['passed'] and tera['tera']==36 and tera['moved_starts']==9 and tera['expansions_checked']==24
worker=read(results/'worker-passages-20261025/result.json');jobs=read(results/'worker-passages-20261025/jobs.json');assert worker['passed'] and jobs['passed']
for name,d in [('tera',tera),('worker',worker),('worker-jobs',jobs)]:
 (qa/(name+'.json')).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for image in ['six-difficulties.png','worker-passage-r0.png','worker-passage-r1.png','worker-passage-r2.png']:shutil.copy2(out/'native-captures'/image,qa/image)
source_files=['scripts/bot_ai.gd','scripts/core.gd','scripts/world_map.gd','scripts/main.gd','scripts/menu_pages.gd','data/game.json','data/resource_spacing_20261025.json','data/original_maps.json','data/source_terrain_detail.json']
hashes={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in source_files}
result={'passed':True,'version':'0.6.4','release':'feedback10-20261025','checks':checks,'source_sha256':hashes,'difficulty':{'measured_reaction_seconds':[round(r['mean_reaction'],2) for r in response['records'][:6]],'first_wave_seconds_by_race':[[round(r['first_wave'],1) for r in d['records']] for d in openings],'scope':'18 actual source-map openings with identical seed and initial resources against an idle opponent; 90 identical-resource timed defense scenarios. First pressure and mean response improve at every level in every race. Victory time is not guaranteed monotonic in every matchup.'}}
(qa/'exports.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
names=['매우 쉬움','쉬움','보통','어려움','매우어려움','헬']
lines=['# 난이도와 자기 건물 사이 통행 검증','',
 '최종 Windows PCK를 소스 파일 없이 탑재해 검증했다. 컴퓨터 상대는 게임 내부의 규칙 AI이며 외부 모델 호출이나 플레이 토큰 비용이 없다.','',
 '| 난이도 | 판단 설정 | 기지당 일꾼 목표 | 첫 파동 전투 병력 | 세 종족 평균 첫 공격 | 평균 기습 대응 |',
 '|---|---:|---:|---:|---:|---:|']
for level,name in enumerate(names):
 wave=sum(d['records'][level]['first_wave'] for d in openings)/3
 lines.append(f'| {name} | {[6,4.5,2.5,1,.65,.35][level]}초 | {[8,12,16,18,22,24][level]}기 | {[14,12,10,8,6,4][level]}기 | {wave:.1f}초 | {response["records"][level]["mean_reaction"]:.2f}초 |')
lines.extend(['',
 '첫 공격 전에는 일꾼8기와 기본 생산에 집중하며, 이후 난이도별 일꾼 목표·확장·연구·추가 생산으로 진행한다. 확장 판단 시작480/360/210/160/120/90초는 첫 공격 완료와 실제 자원·건설 조건을 함께 충족해야 한다. 유닛 능력치·자원 수입·안개 속 적 정보 특혜는 없다.',
 '','실험은 같은 투혼 맵·시드251025·시작 자원으로 종족별6경기(총18경기), 동일 자원/병력의 기습 발생 시각5개×6난이도×3종족(90상황)이다. 모든 종족에서 첫 공격과 평균 대응이 단계마다 빨라졌다. 상대 조합과 교전 손실에 따라 개별 승리 시간은 뒤집힐 수 있으며 모든 상대에 대한 승률 순위를 증명한 실험은 아니다.',
 '','자기 일꾼만 자기 건물의 맞닿은 공유 경계1칸 통로를 사용한다. 다른 소유자(동맹 포함), 일반 병력, 건물 내부 전체, 자원·물·돌 절벽에는 허용하지 않는다. 소유자별 경로 캐시·경로 단축·실제 몸체 이동·충돌 보정에 동일 권한을 적용했다.',
 '','세 맵×세 종족 원본 지형과 소유자/동맹/병사/내부/자원/돌/소유권 변경/파괴/모서리 접촉860검사 및 실제 채취·건설12검사 통과. 기존 세 맵×세 종족12기 편대9경우는 궤적·도착 시간·최종 좌표가 수정 전과 동일했다. 정상22경사로44회도 보존했다.',
 '','원본 테라36개를 재대조했다. 승인된 시작9개만1~2칸 보정하고 확장24개는 원본 좌표 그대로다. 아스·지형 이동0. 파이썬 좌하단 섬은 원본 건설 공간상 테라7칸 예외다.',
 '','근거: [최종 검증 결과](verification_feedback10_20261025/exports.json), [실제 경기](verification_feedback10_20261025/opening0.json), [대응 실험](verification_feedback10_20261025/response.json).'])
(root/'docs/DIFFICULTY_WORKERS_20261025.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
if '--committed' in sys.argv:
 sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip();package=checks['archive']
 (out/'release-validation.json').write_text(json.dumps({'passed':True,'commit':sha,'sha256':package['sha256'],'bytes':package['bytes'],'validation':'docs/verification_feedback10_20261025/exports.json'},indent=2)+'\n',encoding='utf-8')
print('FEEDBACK10_VERIFIED',json.dumps(result['difficulty'],ensure_ascii=False))
