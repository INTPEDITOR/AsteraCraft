from pathlib import Path
import json,shutil
root=Path(__file__).resolve().parents[1];out=root/'build/feedback10_20261025';out.mkdir(parents=True,exist_ok=True)
p=root/'project.godot';s=p.read_text(encoding='utf-8');assert 'config/version="0.6.3"' in s or 'config/version="0.6.4"' in s;p.write_text(s.replace('config/version="0.6.3"','config/version="0.6.4"'),encoding='utf-8')
p=root/'data/game.json';data=json.loads(p.read_text(encoding='utf-8'));data['version']='0.6.4';p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
notes='''컴퓨터 난이도 6단계와 일꾼의 자기 건물 사이 통행을 추가하고, 자원 건설 간격과 절벽 시야를 수정했습니다.

- 난이도: 매우 쉬움 / 쉬움 / 보통 / 어려움 / 매우어려움 / 헬.
- 높은 난이도는 더 빨리 판단하고 초반부터 압박합니다. 첫 병력 전에 확장·고급 기술에 과투자하던 순서를 수정했습니다.
- 높은 난이도는 이후 더 많은 일꾼·생산 시설·연구와 집중 공격을 활용합니다. 자원 수입·공격력·체력·시야 특혜는 없습니다.
- 컴퓨터 상대는 게임 안에서 실행됩니다. ChatGPT/OpenAI API 연결이나 플레이 토큰 비용은 없습니다.
- 일꾼은 맞닿은 자기 건물의 경계 사이를 통행합니다. 다른 소유자의 건물(동맹 포함), 일반 병력, 건물 내부 전체, 자원·물·절벽에는 통행 권한을 주지 않습니다.
- 모든 시작 본진의 아스·테라 간격을 2칸으로 맞추고, 확장에서도 같은 제한으로 더 가깝게 건설할 수 있도록 했습니다.
- 원본 맵의 테라 36개를 대조했습니다. 승인된 시작 테라 9개만 1~2칸 보정하며 확장 테라 24개와 아스·지형은 이동하지 않습니다.
- 파이썬 좌하단 섬은 원본 건설 공간 때문에 가장 가까운 테라 간격이 7칸입니다. 지형을 열거나 테라를 옮기지 않았습니다.
- 돌 절벽의 발판 높이와 시야 계산, 밀림 보정의 충돌을 수정했습니다. 정상 경사로와 기존 편대 경로는 유지합니다.

기존 게임의 메인 화면에서 업데이트하거나 새 ZIP을 모두 풀어 AsteraCraft.exe를 실행하세요.
이전 온라인 대기실의 쉬움/보통/어려움 설정은 기존 의미를 유지합니다. 새 6단계 선택은 싱글플레이에서 제공합니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES10_20261025.md').write_text('# 난이도·일꾼 통행·맵 수정판\n\n'+notes,encoding='utf-8')
for src,dst in [('assets/game_icon.ico','game_icon.ico'),('assets/fonts/OFL-LevelUp.txt','LICENSES-LevelUp.txt')]:shutil.copy2(root/src,out/dst)
(out/'README.txt').write_text('아스테라크래프트 0.6.4 — 난이도·일꾼 통행·맵 수정판\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback10-20261025\n',encoding='utf-8')
for name in ['publish','verify_public']:
 src='publish_feedback9_20261025.cjs' if name=='publish' else 'verify_feedback9_public_20261025.cjs'
 dst='publish_feedback10_20261025.cjs' if name=='publish' else 'verify_feedback10_public_20261025.cjs'
 s=(root/'tools'/src).read_text(encoding='utf-8')
 s=s.replace('feedback9_20261025','feedback10_20261025').replace('feedback9-20261025','feedback10-20261025').replace('feedback8-20261025','feedback9-20261025').replace('이동·근접 공격 수정판','난이도·일꾼 통행·맵 수정판')
 (root/'tools'/dst).write_text(s,encoding='utf-8')
s=(root/'tests/feedback9_pack_test.gd').read_text(encoding='utf-8').replace('feedback9-20261025','feedback10-20261025').replace('0.6.3','0.6.4').replace('FEEDBACK9_PACK','FEEDBACK10_PACK')
s=s.replace('\tvar manifest=', '\tassert(preload("res://scripts/bot_ai.gd").NAMES.size()==6)\n\tvar manifest=',1)
(root/'tests/feedback10_pack_test.gd').write_text(s,encoding='utf-8')
print('FEEDBACK10_PREPARED')
