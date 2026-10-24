from pathlib import Path
import json
import shutil

root=Path(__file__).resolve().parents[1]
out=root/'build/feedback9_20261025'
qa=root/'docs/verification_feedback9_20261025'
out.mkdir(parents=True,exist_ok=True)
qa.mkdir(parents=True,exist_ok=True)
for folder in ['verification_movement_20261025','verification_move_attack_20261025']:
    result=json.loads((root/'docs'/folder/'summary.json').read_text(encoding='utf-8'))
    assert result['passed']
    shutil.copy2(root/'docs'/folder/'summary.json',qa/(folder+'-source.json'))

notes='''우클릭 이동과 근접 공격의 멈칫·정체를 개선하고 굴착포 전차의 고정 사거리를 늘렸습니다.

- 경로 재계산을 기다릴 때 기존의 안전한 경로를 계속 따라갑니다.
- 정지 아군을 우회한 경로가 직선 최적화에서 다시 잘리지 않도록 수정했습니다.
- 같은 편대의 도착 자리 점유와 정지 아군 사이 양보 교착을 개선했습니다.
- 새 이동 명령 뒤에 이전 공격 대상·포위 예약이 남던 문제를 수정했습니다.
- 근접 유닛이 경로 계산 대기를 접근 불가로 판단해 멈추던 문제를 수정했습니다.
- 굴착포 전차 고정 사거리: 10 → 12. 기동 사거리 7과 최소 사거리 2.5는 유지합니다.
- 실제 사거리, 자동 대상 탐색, 정보창과 전개 설명을 일치시켰습니다.

기존 게임의 메인 화면에서 업데이트를 받거나 새 ZIP을 모두 풀어 AsteraCraft.exe를 실행하세요.
장거리 사격에는 기존처럼 아군 시야가 필요합니다. 다른 유닛의 수치와 원본 맵 통행 자료·원화는 유지합니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES9_20261025.md').write_text('# 이동·근접 공격 수정판 2026-10-25\n\n'+notes+'\n배포 검증: verification_feedback9_20261025/exports.json\n',encoding='utf-8')
shutil.copy2(root/'assets/game_icon.ico',out/'game_icon.ico')
shutil.copy2(root/'assets/fonts/OFL-LevelUp.txt',out/'LICENSES-LevelUp.txt')
(out/'README.txt').write_text('아스테라크래프트 0.6.3 — 이동·근접 공격 수정판2026-10-25\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback9-20261025\n',encoding='utf-8')
publisher=(root/'tools/publish_feedback8_20261025.cjs').read_text(encoding='utf-8').replace('feedback8_20261025','feedback9_20261025').replace('feedback8-20261025','feedback9-20261025').replace('게임 메뉴 수정판','이동·근접 공격 수정판')
(root/'tools/publish_feedback9_20261025.cjs').write_text(publisher,encoding='utf-8')
public=(root/'tools/verify_feedback8_public_20261025.cjs').read_text(encoding='utf-8').replace('feedback8_20261025','feedback9_20261025').replace('feedback8-20261025','feedback9-20261025').replace('feedback7-20261024','feedback8-20261025')
(root/'tools/verify_feedback9_public_20261025.cjs').write_text(public,encoding='utf-8')
native=(root/'tests/feedback8_pack_test.gd').read_text(encoding='utf-8').replace('feedback8-20261025','feedback9-20261025').replace('FEEDBACK8_PACK','FEEDBACK9_PACK')
native=native.replace('var manifest=JSON.parse_string', 'assert(ACData.get_data().version=="0.6.3" and ACData.attack_range(ACData.unit(0,5),true)==12.0)\n\tvar manifest=JSON.parse_string',1)
(root/'tests/feedback9_pack_test.gd').write_text(native,encoding='utf-8')
visual=(root/'work/siege_range_visual_20261025.gd').read_text(encoding='utf-8')
visual=visual.replace('extends "res://tests/view_input_v03_test.gd"\nconst OUT="res://build/move-attack-followup-20261025/visual/"\n','''extends SceneTree
var main: Control
var checks=0
var failures: Array=[]
var OUT=""
func _initialize() -> void:
\tOUT=OS.get_cmdline_user_args()[0].trim_suffix("/")+"/"
\tcall_deferred("run")
func frames(count: int=3) -> void:
\tfor index in range(count):await process_frame
func check(value: bool,message: String) -> void:
\tchecks+=1
\tif not value:failures.append(message);printerr("FAIL: "+message)
''').replace('res://tests/menu_v04_harness.gd','res://scripts/main.gd')
(root/'tests/siege_range_release_capture_20261025.gd').write_text(visual,encoding='utf-8')
print('FEEDBACK9_PREPARED')
