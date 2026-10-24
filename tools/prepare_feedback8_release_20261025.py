from pathlib import Path
import json
import shutil

root=Path(__file__).resolve().parents[1]
out=root/'build/feedback8_20261025'
qa=root/'docs/verification_feedback8_20261025'
out.mkdir(parents=True,exist_ok=True)
qa.mkdir(parents=True,exist_ok=True)
source=root/'build/pause-menu-20261025'
result=json.loads((source/'result.json').read_text(encoding='utf-8'))
assert result['passed'] and result['checks']==107 and result['factions']==3
shutil.copy2(source/'result.json',qa/'source-menu-validation.json')
for race in range(3):shutil.copy2(source/f'pause-r{race}.png',qa/f'pause-r{race}.png')
notes='''게임 메뉴의 빈 줄과 불필요한 스크롤을 수정했습니다.

- 노바너·이귤·아라아울 모두 계속하기 / 환경 설정 / 항복 / 메인 화면 네 버튼을 동일한 간격과 위치로 배치했습니다.
- 삭제된 버튼의 빈 줄을 없애고 제목과 버튼을 창 가운데에 정렬했습니다.
- 짧은 메뉴에 생기던 가로·세로 스크롤을 없앴습니다.
- “온라인 경기는 메뉴를 열어도 계속 진행됩니다.” 안내 문구를 삭제했습니다.
- 기존 종족별 버튼·창 원화와 싱글플레이 일시정지 / 재개, 온라인 진행 방식은 유지합니다.

기존 게임 메인 화면에서 업데이트 받기를 누르거나, 새 ZIP을 모두 풀어 AsteraCraft.exe를 실행하세요.

이번 변경은 게임 메뉴 수정입니다. 새 홍보 이미지나 새로운 핵 폭발 효과음은 게임에 추가하지 않았습니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES8_20261025.md').write_text('# 게임 메뉴 수정판 2026-10-25\n\n'+notes+'\n검증: verification_feedback8_20261025/exports.json\n',encoding='utf-8')
shutil.copy2(root/'assets/game_icon.ico',out/'game_icon.ico')
shutil.copy2(root/'assets/fonts/OFL-LevelUp.txt',out/'LICENSES-LevelUp.txt')
(out/'README.txt').write_text('아스테라크래프트 0.6.2 — 게임 메뉴 수정판2026-10-25\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback8-20261025\n',encoding='utf-8')
# Reuse the validated release checks with only the new release identity.
for old,new in [('tests/feedback7_pack_test.gd','tests/feedback8_pack_test.gd'),('tools/test_feedback7_pack_export_20261024.cjs','tools/test_feedback8_pack_export_20261025.cjs'),('tools/publish_feedback7_20261024.cjs','tools/publish_feedback8_20261025.cjs')]:
    text=(root/old).read_text(encoding='utf-8').replace('feedback7_20261024','feedback8_20261025').replace('feedback7-20261024','feedback8-20261025').replace('feedback7_pack_test','feedback8_pack_test').replace('FEEDBACK7_PACK','FEEDBACK8_PACK')
    text=text.replace('AsteraCraft 화면 경계·공중 부유 수정판 - 2026-10-24','AsteraCraft 게임 메뉴 수정판 - 2026-10-25')
    (root/new).write_text(text,encoding='utf-8')
script=(root/'work/pause-menu-capture-20261025.gd').read_text(encoding='utf-8')
script=script.replace('extends "res://tests/view_input_v03_test.gd"\nconst OUT="res://build/pause-menu-20261025/"\n','''extends SceneTree
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
(root/'tests/pause_menu_release_capture_20261025.gd').write_text(script,encoding='utf-8')
print('FEEDBACK8_PREPARED source_menu_checks='+str(result['checks']))
