"""Prepare the approved release without repeating completed gameplay tests."""
from pathlib import Path
import json,shutil,time
root=Path(__file__).resolve().parents[1]
out=root/'build/feedback12_20261026';out.mkdir(parents=True,exist_ok=True)
version='0.6.6';tag='feedback12-20261026'
p=root/'project.godot';s=p.read_text(encoding='utf-8');p.write_text(s.replace('config/version="0.6.5"','config/version="0.6.6"'),encoding='utf-8')
p=root/'data/game.json';g=json.loads(p.read_text(encoding='utf-8'));g['version']=version;p.write_text(json.dumps(g,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'data/update_channel.json').write_text(json.dumps({'repository':'INTPEDITOR/AsteraCraft','tag':tag,'built_at_unix':int(time.time()),'channel':'official'},indent=2)+'\n',encoding='utf-8')
notes='''승인한 종족별 전술75개와 헬 난이도 보강, 건물 사이 중앙선 통행, 근접 공격속도 조정을 반영했습니다.

- 노바너·이귤·아라아울의 전술을25개씩 연결했습니다. 난이도별 전술 폭은3/6/12/18/23/25개로 넓어집니다.
- 헬은 더 빠른 판단과 정찰 정보에 따른 조합 선택, 실제 기술·연구·공성·수송·핵 운용을 사용합니다. 자원·능력치 특혜나 외부 AI API/토큰 사용은 없습니다.
- 본진에서 부대를 만든 뒤 적 앞에서 집결하고 함께 진입합니다. 부상·손실 시 재집결하며, 소수 정찰에는 가까운 방어대가 대응합니다.
- 자기 일꾼은 붙은 자기 건물의 공유 경계선 중앙으로 통행합니다. 다른 소유자의 건물·일반 병력·자원·지형 차단 규칙은 유지합니다.
- 건물 통행 경로 갱신의 전체 맵 재계산을 줄였습니다. 모든 지연이 사라졌다는 뜻은 아닙니다.
- 싱글플레이 컴퓨터가 같은 종족으로도 추첨됩니다. 참가자 색은 겹치지 않습니다.
- 포낭비행체의 화면 크기를 키웠습니다.
- 근접 공격 주기: 돌격병0.75→0.65초, 방패보병1→0.8초, 껍질발톱0.65→0.55초, 후피거수1→0.85초, 접목충0.9→0.8초, 서약수호자1.15→0.95초, 황혼잠행자1.3→1.1초.

기존 메인 화면에서 업데이트하거나 ZIP 전체를 풀어 AsteraCraft.exe를 실행하세요.
EXE/PCK/DLL은 같은 폴더에 두세요. 멀티플레이 참가자는 같은 최신 버전을 사용하세요.

이미 완료한 소스 검증 결과를 사용했습니다. 사용자 요청에 따라 이번 게시 과정에서 게임·실행·업데이터 검사를 반복하지 않았습니다.
'''
(out/'release-notes.md').write_text(notes,encoding='utf-8')
(root/'docs/FEEDBACK_FIXES12_20261026.md').write_text('# 전술·헬·일꾼 중앙 통행 수정판\n\n'+notes,encoding='utf-8')
for src,dst in [('assets/game_icon.ico','game_icon.ico'),('assets/fonts/OFL-LevelUp.txt','LICENSES-LevelUp.txt')]:shutil.copy2(root/src,out/dst)
(out/'README.txt').write_text(f'아스테라크래프트 {version}\n\nZIP 전체를 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/{tag}\n',encoding='utf-8')
p=root/'README.md';s=p.read_text(encoding='utf-8').replace('v0.6.5','v0.6.6').replace('feedback11-20261025','feedback12-20261026').replace('이전 v0.6.4','이전 v0.6.5')
start=s.index('## 현재 버전');end=s.index('## 게임 기능',start)
s=s[:start]+'''## 현재 버전

- 세 종족의 승인 전술75개, 난이도별 전술 폭 확대와 헬 판단·정찰·기술·집결 운용을 반영했습니다.
- 자기 일꾼은 붙은 자기 건물의 공유 경계 중앙으로 통행합니다. 경로 갱신의 전체 맵 재계산을 줄였습니다.
- 싱글플레이 동족전 추첨·색상 중복 방지, 포낭비행체 확대와7종 근접 공격속도 상향을 반영했습니다.
- [이번 수정 내역](docs/FEEDBACK_FIXES12_20261026.md), [기존 검증 결과](docs/AI_TACTICS_IMPLEMENTED_20261026.md).
- 사용자 요청에 따라 배포 시 게임·실행·업데이터 검사를 반복하지 않았습니다.

'''+s[end:]
p.write_text(s,encoding='utf-8')
# Keep the already established publisher; no source/game test runners here.
s=(root/'tools/publish_feedback11_20261025.cjs').read_text(encoding='utf-8')
s=s.replace('feedback11_20261025','feedback12_20261026').replace('feedback11-20261025','feedback12-20261026')
s=s.replace('AsteraCraft 자원·안개·화면 경계·AI 수정판 - 2026-10-25','AsteraCraft 전술·헬·일꾼 중앙 통행 수정판 - 2026-10-26')
(root/'tools/publish_feedback12_20261026.cjs').write_text(s,encoding='utf-8')
print('FEEDBACK12_PREPARED')
