from pathlib import Path
import json, shutil

root=Path(__file__).resolve().parents[1]
out=root/'build/feedback5_20261024'
qa=root/'docs/verification_feedback5_20261024'
out.mkdir(parents=True,exist_ok=True);qa.mkdir(parents=True,exist_ok=True)
result=json.loads((root/'build/egyul-ui-applied-20261024/result.json').read_text(encoding='utf-8'))
assert result['passed'] and len(result['resolutions'])==18
shutil.copyfile(root/'build/egyul-ui-applied-20261024/result.json',qa/'checks.json')
for name in ['main-menu','single-menu','settings','room','hud-r0','hud-r1','hud-r2','edge-1440x900','edge-1920x800']:
    shutil.copyfile(root/'build/egyul-ui-applied-20261024'/f'{name}.png',qa/f'{name}.png')
manifest=json.loads((root/'data/egyul_native_ui_20261024.json').read_text(encoding='utf-8'))
manifest['verification']='docs/verification_feedback5_20261024/checks.json'
(root/'data/egyul_native_ui_20261024.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
notes='''승인된 이귤 버튼·창 테두리와 세 종족 공통 UI 배치를 적용했습니다.

- 새 이귤 버튼4종과 창 테두리5종을 각 최종 크기로 연결했습니다. 새 원화를 늘이거나 나인패치로 변형하지 않습니다.
- 세 종족 메인 버튼은320×76, 일반 메뉴·선택상자는220×48로 맞췄습니다. 같은 메뉴의 창 기준 크기, 안쪽 여백과 버튼 좌표도 같습니다.
- 이귤 초상화·미니맵·명령 아이콘을 승인 원화의 실제 창 중앙에 맞췄습니다. 기존 HUD 원본과 다른 종족의 외형은 보존했습니다.
- 화면 비율이 달라질 때 생기는 좌우·하단 검은 여백을 없애고 HUD가 화면 가장자리에 붙도록 했습니다. 해상도 변경 즉시 명령 아이콘과 클릭 영역도 함께 이동합니다.
- 테두리 위로 삐져나오던 검은 배경판을 제거하고, 대기실 버튼이 겹치지 않게 정리했습니다.

실제 메뉴·전투 HUD에서 크기/좌표/아이콘 정렬을 확인했습니다. 세 종족과 해상도6종의18가지 조합에서 화면 가장자리·명령 클릭 영역을 비교했습니다. Windows 실행·패키지·이전 버전 업데이트 검증 결과는 소스의 검증 자료를 참조하세요.

기존 실행파일의 메인 화면에서 업데이트 받기를 누르거나 새 ZIP을 모두 풀어 실행하세요. 이전 배포물은 보존합니다. 새 핵 폭발음은 이번 UI 수정에 포함되지 않았으며 기존 음원을 유지합니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES5_20261024.md').write_text('# 2026-10-24 이귤 UI·공통 배치 수정\n\n'+notes+'\n검증: `verification_feedback5_20261024/checks.json`. 원화 생성 모드는 built-in image_gen이며,9개 최종 파일과 각 프롬프트/출처는 `data/egyul_native_ui_20261024.json`의 prompt_record를 따릅니다.\n',encoding='utf-8')
shutil.copyfile(root/'assets/game_icon.ico',out/'game_icon.ico')
shutil.copyfile(root/'assets/fonts/OFL-LevelUp.txt',out/'LICENSES-LevelUp.txt')
(out/'README.txt').write_text('아스테라크래프트 — 이귤 UI·공통 배치 수정판 2026-10-24\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback5-20261024\n',encoding='utf-8')
print('FEEDBACK5_REVIEW_ARTIFACTS_READY')
