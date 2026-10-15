# 아스테라크래프트 (AsteraCraft) v0.5.6

Godot 4.6으로 제작한 Windows용 2D 실시간 전략 게임입니다. 바위너구리 연합, 귤 변이 군체, 고대 부엉이 문명 중 하나를 선택해 아스와 테라를 채취하고 전투합니다.

## 다운로드와 실행

[최신 Windows 실행 파일](https://github.com/INTPEDITOR/AsteraCraft/releases/latest)에서 `AsteraCraft-Windows-v0.5.6-20261016.zip`을 받으세요. **ZIP을 전부 압축 해제한 뒤 `AsteraCraft.exe`를 실행**합니다. EXE 옆의 PCK, `server`, `runtime` 폴더를 함께 유지하세요.

Windows 64비트와 OpenGL 3.3 지원 환경이 필요합니다. 실행 패키지에는 필요한 런타임이 포함되어 있습니다. 멀티플레이 참가자는 모두 같은 버전을 사용하세요. 현재 멀티플레이는 로컬/LAN 환경을 대상으로 합니다.

## 현재 버전

- 본진 바로 아래에 일꾼 4명을 가로로 배치하고 가까운 아스를 자동 채취합니다. 실제 접근 경로와 왕복 거리를 비교하며 광물의 본진 반대편 면은 자동 접근 후보에서 제외합니다.
- 채취·반납 중인 일꾼은 다른 유닛을 통과합니다. 지형·건물·자원은 이동을 막습니다.
- 투혼·파이썬·로스트템플의 원본 배치와 타일 기반 지형을 적용했습니다. 이동 충돌은 게임의 32픽셀 격자를 사용합니다. 원본 맵 바이너리와 StarCraft 설치 데이터는 저장소에 포함하지 않습니다.
- 군체모수에서 12칸 이내 추가배양낭의 생산·취소·집결을 통합 관리합니다. 연결 소실 시 생성·변태를 멈추고 재연결 시 이어갑니다.
- 군체모수·뿌리중계체 주변 13칸에 뿌리 지대를 표시합니다. 군체모수를 제외한 귤 건물은 전체 건설 칸이 자신의 뿌리 지대 안에 있어야 합니다.
- 껍질발톱은 아스 50으로 2마리 생산하며 총 인구수는 1입니다.
- 접목충의 Q 정신 조종과 어택땅의 아군 공격자 우선 표적을 지원합니다.
- 건물 메뉴의 자원·정보 표시, 초상화 잘림, 테라 건설 좌표와 일꾼 경로를 수정했습니다.

자세한 내용은 [변경 기록](docs/changes-v056.txt)을 확인하세요. 외부 TTS 교체, 공개 인터넷 로비 운영, 장시간 경쟁 밸런스 검증은 남아 있습니다.

## 기본 조작

| 입력 | 동작 |
|---|---|
| 좌클릭 / 드래그 | 선택 / 최대 12기 선택 |
| 우클릭 | 이동·공격·아스 채취 등 상황별 명령 |
| A → 좌클릭 | 공격 이동 |
| B | 일꾼 건설 메뉴 |
| Q / S / H | 특수 기능 / 정지 / 위치 사수 |
| R → 좌클릭 | 생산 건물 집결 지점 |
| Ctrl + 1~9 / 1~9 | 부대 저장 / 선택 |
| Space / 미니맵 클릭 | 본진 보기 / 카메라 이동 |
| 휠 / Esc | 확대·축소 / 명령 취소·전투 메뉴 |

## 소스 실행과 빌드

Godot 4.6에서 `project.godot`를 열어 실행합니다. 온라인 개발 서버에는 Node.js와 Godot 실행 파일이 필요합니다. 서버는 Node.js 내장 모듈만 사용합니다.

```powershell
godot --headless --path . --editor --import
godot --headless --path . --export-release "Windows Desktop" build/AsteraCraft.exe
node server/server.js
```

Windows 내보내기는 Godot 4.6의 Windows x86_64 템플릿을 설치한 뒤 사용하세요. 소스에는 Godot·Node 실행 파일, 빌드 캐시, 로컬 계정 데이터가 포함되지 않습니다. 이 작업 환경용 `tools_run_godot.js`와 패키징 스크립트의 경로는 다른 PC에서 조정해야 합니다.

주요 검증은 `tests/auto_mining_v056_test.gd`, `tests/tera_map_audit_test.gd`, `tests/colony_root_threat_test.gd`, `tests/original_maps_control_test.gd`입니다. Godot에서 `--headless --path . --script tests/이름.gd`로 실행할 수 있습니다. 일부 검사는 `build` 폴더를 먼저 만들어야 합니다.

## 제작 자료와 고지

유닛·건물·지면·메뉴 그림은 이미지 생성으로 제작했으며 효과음과 사망 소리는 합성 제작했습니다. BGM은 사용자 제공 파일입니다. Godot·글꼴의 라이선스 고지는 `licenses`, Node.js 고지는 `runtime/Node-LICENSE.txt`에 있습니다.
