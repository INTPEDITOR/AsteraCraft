from pathlib import Path
import json, shutil

root = Path(__file__).resolve().parents[1]
out = root / 'build/feedback7_20261024'
qa = root / 'docs/verification_feedback7_20261024'
out.mkdir(parents=True, exist_ok=True)
qa.mkdir(parents=True, exist_ok=True)
sources = {
    'camera-geometry': 'build/camera-edges-20261024/geometry.json',
    'camera-screens': 'build/camera-edges-20261024/visual.json',
    'air-hover': 'build/air-hover-20261024/result.json',
}
summary = {}
for name, file in sources.items():
    data = json.loads((root / file).read_text(encoding='utf-8'))
    assert data['passed'], (name, data.get('failures'))
    shutil.copyfile(root / file, qa / (name + '.json'))
    summary[name] = {'passed': True, 'checks': data['checks']}
for name in ['m0-r0-north-after', 'm0-r0-south-after', 'm0-r1-south-after', 'm0-r2-south-after']:
    shutil.copyfile(root / 'build/camera-edges-20261024' / (name + '.png'), qa / (name + '.png'))
shutil.copyfile(root / 'build/air-hover-20261024/idle-00.png', qa / 'aircraft-idle.png')
(qa / 'source-validation.json').write_text(json.dumps({'passed': True, 'checks': summary}, indent=2), encoding='utf-8')
notes = '''화면 상하 경계와 공중 유닛의 정지 부유를 수정했습니다.

- 위쪽 끝에서 실제 높이 지형이 가려지던 현상을 수정했습니다. 현재 화면에 보이는 북쪽 지형 높이를 기준으로 카메라가 끝까지 접근하며, 지형을 덮던 중복 가림 영역도 바로잡았습니다.
- 아래쪽은 세 종족 HUD의 실제 굴곡을 기준으로 카메라 한계를 맞췄습니다. 지형이 HUD 뒤까지 이어지도록 얇은 여유를 두어 검은 틈을 막았습니다.
- 지형 표면·강둑·바위의 경계 정점을 같은 높이 기준으로 그립니다. 원본 맵의 이동 경로·높이 자료·자원 위치는 변경하지 않았습니다.
- 공중 유닛12종이 정지해 있을 때 작고 부드럽게 떠 있는 움직임을 복구했습니다. 고정 선체도 부유하며 공격/이동 명령이 바뀌어도 부유 위상이 초기화되지 않습니다. 선택 원과 지면 그림자는 그대로 두고, 정지 중 추진 불꽃은 켜지지 않습니다.

승인된 UI 원화와 16:9 화면비는 유지합니다. 기존 게임을 다시 실행한 뒤 메인 화면의 업데이트 받기를 누르면 설치할 수 있습니다.

검증: 세 맵·세 종족·세 확대율의 카메라 계산189경우, 실제 경계18화면, 공중 유닛12종의 정지16장면, Windows 실행 및 이전 버전에서 업데이트 교체/재시작을 확인했습니다. 검증 기록: docs/verification_feedback7_20261024.

새 핵 폭발음은 이 수정판에 포함되지 않습니다.
'''
(out / 'release-notes.md').write_text(notes, encoding='utf-8')
shutil.copyfile(root / 'assets/game_icon.ico', out / 'game_icon.ico')
shutil.copyfile(root / 'assets/fonts/OFL-LevelUp.txt', out / 'LICENSES-LevelUp.txt')
(out / 'README.txt').write_text('아스테라크래프트 — 화면 경계·공중 부유 수정판2026-10-24\n\n압축을 모두 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback7-20261024\n', encoding='utf-8')
print('FEEDBACK7_REVIEW_ARTIFACTS_READY', json.dumps(summary))
