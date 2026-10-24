from pathlib import Path
import json,shutil
root=Path(__file__).resolve().parents[1]
out=root/'build/feedback6_20261024';qa=root/'docs/verification_feedback6_20261024'
out.mkdir(parents=True,exist_ok=True);qa.mkdir(parents=True,exist_ok=True)
sources={'checks':'build/egyul-ui-aspect16x9-20261024/result.json','captions':'build/menu-caption-20261024/result.json','aspect':'build/aspect16x9-20261024/result.json','no-replay':'build/replay-removed-20261024/result.json','startup':'build/feedback4-20261024/startup-preferences-result.json'}
summary={}
for name,file in sources.items():
    data=json.loads((root/file).read_text(encoding='utf-8'));assert data['passed'],(name,data.get('failures'))
    shutil.copyfile(root/file,qa/(name+'.json'));summary[name]={'passed':True,'checks':data['checks']}
assert len(json.loads((qa/'checks.json').read_text())['resolutions'])==18
for name in ['single-menu','account','room','queue-r1','hud-r0','hud-r1','hud-r2','surrender','edge-1440x900','edge-1920x800']:
    shutil.copyfile(root/'build/egyul-ui-aspect16x9-20261024'/f'{name}.png',qa/f'{name}.png')
inventory=root/'build/faction-button-inventory-20261024/inventory.json'
d=json.loads(inventory.read_text());assert not d['control_size_mismatches'];shutil.copyfile(inventory,qa/'button-inventory.json')
summary['buttons']={'contexts':d['contexts'],'factions':d['factions'],'control_size_mismatches':[]}
(qa/'source-validation.json').write_text(json.dumps({'passed':True,'published':False,'checks':summary},indent=2),encoding='utf-8')
manifest=json.loads((root/'data/egyul_native_ui_20261024.json').read_text(encoding='utf-8'));manifest['verification']='docs/verification_feedback6_20261024/checks.json'
(root/'data/egyul_native_ui_20261024.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
notes='''승인된 이귤 HUD·버튼·창 배경을 적용하고 화면비와 리플레이 잔존 기능을 수정했습니다.

- 일반 창·전체 화면·경계 없는 전체 화면 모두16:9를 유지합니다. 넓은 모니터의 여백은 게임 화면 바깥에 두고 시야/HUD를21:9로 늘리지 않습니다.
- 자연스러운 뿌리 윤곽을 살린 승인 이귤 HUD를 한 장의1600×269원화로 연결했습니다. 양옆·아래쪽 경계와 정보창 아래 여백을 정리했습니다.
- 이귤 일반·선택 버튼은220×48에서 중앙 판과 상하 높이를 보완한 승인본으로 교체했습니다. 대기실 소형105×36은 세 종족 공통 디자인으로 통일했습니다. 생산·연구 대기열도90×32로 맞췄습니다.
- 버튼 글자는 화살표 예약 공간과 글꼴 높이 대신 실제 표시 글자 영역을 기준으로 중앙 정렬합니다. 로딩 연결 취소도 세 종족 모두220×48입니다. 컴퓨터 수는1명/2명/3명만 표시하고, 색상 견본과 색 이름을 가까이 묶어 중앙에 배치했습니다. 이귤 항복 요청 창의 내용도 세로 중앙으로 맞췄습니다.
- 이귤 큰 창1260×840/중간 창1060×840의 투명 얼룩을 없애고 균일한 짙은 판으로 채웠습니다. 새 판 아래에 중복 배경을 그리지 않습니다.
- 리플레이 기록·저장·재생·메뉴와 관련 버튼을 제거했습니다. 기존 사용자 파일은 삭제하지 않습니다. 실시간 관전은 유지합니다.

각 새 UI원화는 해당 고정 크기에서1:1로 표시하며 늘이기/나인패치를 사용하지 않습니다. 이전 원본과 릴리스는 보존합니다.

기존 게임 메인 화면의 업데이트 받기로 설치하거나 새 ZIP을 모두 풀어 실행하세요. Windows 실행·패키지·이전 버전 실제 교체/재시작 검증은 배포 검증 자료로 확인합니다. 인터넷/LAN대전은 이번 UI수정에서 새로 검증하지 않았으며 새 핵 폭발음도 포함하지 않았습니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES6_20261024.md').write_text('# 2026-10-24 승인 UI·16:9·리플레이 제거\n\n'+notes+'\n검증 자료: verification_feedback6_20261024/source-validation.json.\n',encoding='utf-8')
shutil.copyfile(root/'assets/game_icon.ico',out/'game_icon.ico');shutil.copyfile(root/'assets/fonts/OFL-LevelUp.txt',out/'LICENSES-LevelUp.txt')
(out/'README.txt').write_text('아스테라크래프트 — 승인 UI·화면비 수정판2026-10-24\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback6-20261024\n',encoding='utf-8')
print('FEEDBACK6_REVIEW_ARTIFACTS_READY',json.dumps(summary))
