from pathlib import Path
import json,shutil
root=Path(__file__).resolve().parents[1];out=root/'build/feedback11_20261025';out.mkdir(parents=True,exist_ok=True)
p=root/'project.godot';text=p.read_text(encoding='utf-8');assert 'config/version="0.6.4"' in text or 'config/version="0.6.5"' in text
p.write_text(text.replace('config/version="0.6.4"','config/version="0.6.5"'),encoding='utf-8')
p=root/'data/game.json';data=json.loads(p.read_text(encoding='utf-8'));data['version']='0.6.5';p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
notes='''본진 자원 간격, 같은 층의 검은 안개, 화면 가장자리와 컴퓨터의 공격 집결 방식을 수정했습니다.

- 본진과 아스, 테라·정제 건물 사이의 최소 간격을 실제 지면 경계 기준 3칸으로 통일했습니다. 시작 12곳과 멀티 30곳을 확인했습니다.
- 시작 테라의 이전 위치 보정을 제거해 테라 36곳 모두 원본 맵 좌표로 복원했습니다. 원본 광물·지형·통로는 유지합니다.
- 파이썬의 작은 섬 두 곳은 원본의 채굴량 1짜리 광물을 먼저 채취하면 3칸 간격으로 본진을 건설할 수 있습니다. 섬을 넓히거나 거리 예외를 추가하지 않았습니다.
- 실제 지형 높이와 안개 투영이 어긋나 같은 층의 보이는 지면이 검게 가려지던 문제를 수정했습니다. 고지대 은폐, 피격 시 잠깐 보이는 시야, 공중 시야 규칙은 유지합니다.
- 최상단 유닛의 몸체와 체력·실드 표시를 볼 수 있도록 카메라와 외곽 가림 순서를 수정했습니다. 위쪽은 필요한 여유를 허용합니다.
- 왼쪽·오른쪽·아래쪽은 맵 밖 검은 공간이 드러나지 않는 경계까지 이동합니다. 아래 지형은 HUD의 굴곡 뒤까지 채웁니다. 16:9 화면비는 유지합니다.
- 컴퓨터 병력은 적진 앞의 안전한 지점에서 느린 동료까지 기다린 뒤 함께 진입합니다. 보충 병력도 무리로 합류하고, 큰 손실이나 부상 시 재집결하며 본진 방어를 우선합니다.
- 화면 이동마다 안개 지형을 다시 그리지 않도록 보관해 화면 이동 성능을 유지했습니다.

기존 게임 메인 화면에서 업데이트하거나 ZIP을 모두 풀어 AsteraCraft.exe를 실행하세요.
EXE/PCK/DLL을 같은 폴더에 두세요. 컴퓨터 상대는 게임 자체 AI이며 외부 모델 호출이나 토큰 사용이 없습니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES11_20261025.md').write_text('# 자원·안개·화면 경계·AI 수정판\n\n'+notes,encoding='utf-8')
for src,dst in [('assets/game_icon.ico','game_icon.ico'),('assets/fonts/OFL-LevelUp.txt','LICENSES-LevelUp.txt')]:shutil.copy2(root/src,out/dst)
(out/'README.txt').write_text('아스테라크래프트 0.6.5 — 자원·안개·화면 경계·AI 수정판\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback11-20261025\n',encoding='utf-8')
for src,dst in [('publish_feedback10_20261025.cjs','publish_feedback11_20261025.cjs'),('verify_feedback10_public_20261025.cjs','verify_feedback11_public_20261025.cjs')]:
 text=(root/'tools'/src).read_text(encoding='utf-8').replace('feedback10_20261025','feedback11_20261025').replace('feedback10-20261025','feedback11-20261025').replace('feedback9-20261025','feedback10-20261025').replace('난이도·일꾼 통행·맵 수정판','자원·안개·화면 경계·AI 수정판')
 (root/'tools'/dst).write_text(text,encoding='utf-8')
text=(root/'tests/feedback10_pack_test.gd').read_text(encoding='utf-8').replace('feedback10-20261025','feedback11-20261025').replace('0.6.4','0.6.5').replace('FEEDBACK10_PACK','FEEDBACK11_PACK')
text=text.replace('\tvar manifest=', '\tassert(ACMap.HQ_MINERAL_GAP==3 and ACMap.HQ_TERA_GAP==3)\n\tvar manifest=',1)
(root/'tests/feedback11_pack_test.gd').write_text(text,encoding='utf-8')
print('FEEDBACK11_PREPARED')
