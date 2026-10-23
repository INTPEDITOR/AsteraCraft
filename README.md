> [2026-10-24 sprite preview / Windows download](https://github.com/INTPEDITOR/AsteraCraft/releases/tag/sprites-20261024) - all44 unit sprites connected, missing42 attack poses added; quick checks139/0. Full visual review of23 units remains deferred. [Report](docs/RELEASE_SPRITES_20261024.md).

# 아스테라크래프트 (AsteraCraft) v0.5.8

Godot 4.6으로 제작한 Windows용 2D 실시간 전략 게임입니다. 바위너구리 연합, 귤 변이 군체, 고대 부엉이 문명 중 하나를 선택해 아스와 테라를 채취하고 전투합니다.

## 다운로드와 실행

[GitHub v0.5.8 다운로드](https://github.com/INTPEDITOR/AsteraCraft/releases/tag/v0.5.8)에서 `AsteraCraft-Windows-v0.5.8-voicefx-20261018.zip`을 받으세요. **ZIP 전체를 압축 해제한 뒤 `AsteraCraft.exe`를 실행**합니다. EXE 옆의 PCK와 WebRTC DLL을 함께 유지하세요.

Windows 64비트와 OpenGL 3.3 지원 환경이 필요합니다. 멀티플레이 참가자는 모두 v0.5.8을 사용하세요. 공개 HTTPS 서비스에서 게임 내 계정·래더·방 목록·연결 정보를 처리하고, 실제 전투는 방장 PC가 호스팅합니다.

WebRTC 직접 연결과 STUN을 사용하며 전투 중계 서버는 없습니다. 엄격한 NAT·방화벽 환경은 연결되지 않을 수 있습니다. 공개 서비스를 거치는 같은 PC 2명+관전자 검증은 통과했으며 서로 다른 인터넷 회선 검증은 남아 있습니다.

## 현재 버전

- 192×96 마름모 지면을 공통 질감 좌표로 연결하고 네 가지 재질을 넓은 구획으로 나눕니다. 세 맵의 물·층간 경계와 경사로, 장식 분포를 보완했습니다. 카메라 뒤쪽 절벽 면은 숨깁니다. HUD 비율과 승인된 비행체 시점은 유지합니다.
- 대형 유닛의 좁은 통로·모서리 이동과 근접 접근 경로를 수정했습니다. 건설 중 일꾼도 유닛 충돌을 무시합니다. 부엉이는 완성된 인구 탑 12칸 범위에 건설하며 탑 자체는 예외입니다. 테라 주기는 3초입니다.
- 비행체 이동에 종족별 8프레임 추진 효과를 추가하고 39종의 기존 지상/차량/비행 이동 표현을 검사했습니다.
- 본진 바로 아래에 일꾼 4명을 가로로 배치하고 가까운 아스를 자동 채취합니다. 실제 접근 경로와 왕복 거리를 비교하며 광물의 본진 반대편 면은 자동 접근 후보에서 제외합니다.
- 채취·반납 중인 일꾼은 다른 유닛을 통과합니다. 지형·건물·자원은 이동을 막습니다.
- 투혼·파이썬·로스트템플의 원본 배치와 타일 기반 지형을 적용했습니다. 이동 충돌은 원본에서 추출한 8픽셀 세부 통행 정보와 유닛 몸체를 사용합니다. 원본 맵 바이너리와 StarCraft 설치 데이터는 저장소에 포함하지 않습니다.
- 군체모수에서 12칸 이내 추가배양낭의 생산·취소·집결을 통합 관리합니다. 연결 소실 시 생성·변태를 멈추고 재연결 시 이어갑니다.
- 군체모수·뿌리중계체 주변에 작은 뿌리 타일이 최대13칸까지 점차 퍼지며 물과 막힌 지형을 넘지 않습니다. 군체모수를 제외한 귤 건물은 전체 건설 칸이 자신의 뿌리 지대 안에 있어야 합니다.
- 껍질발톱은 아스 50으로 2마리 생산하며 총 인구수는 1입니다.
- 접목충의 Q 정신 조종과 어택땅의 아군 공격자 우선 표적을 지원합니다.
- 건물 메뉴의 자원·정보 표시, 초상화 잘림, 테라 건설 좌표와 일꾼 경로를 수정했습니다.

- 종족별 BGM과 메인 화면 음악을 모두 적용했습니다. 메뉴: Echoes of Astera, 바위너구리: Ironbound Frontier, 귤: Seeds of Dominion, 부엉이: Crimson Covenant.

자세한 내용은 [최신 변경 기록](RELEASE_NOTES.md)을 확인하세요. 대규모 밀집 전투 성능, 서로 다른 회선 연결, 외부 TTS 교체, 장시간 경쟁 밸런스 검증은 남아 있습니다.

- 귤 뿌리와 적 건물은 직접 확인한 마지막 상태만 안개 속에 남습니다. 배양체는 일반 유닛을 통과하며 배양체끼리 겹치지 않습니다.
- 본진은 세 종족 모두4×3칸이며 아스 가장자리에서 최소3칸 떨어져야 합니다. 시작 본진도 같은 규칙을 따릅니다.
- 귤행성 메인 화면을 새 뿌리·귤즙 컨셉으로 교체했습니다.
- 음성442개에 바위너구리 무전기, 귤 군체 공명, 부엉이 텔레파시 효과를 적용했습니다.

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

Godot 4.6에서 `project.godot`를 열어 실행합니다. Windows x86_64용 native WebRTC 확장을 포함합니다. 현재 공개 매칭 주소는 `data/public_network.json`에서 읽습니다. 공개 서비스 소스는 별도 상위 `matchmaking-service` 프로젝트에 있습니다. `server/server.js`는 과거 로컬 개발용이며 새 배포 패키지에서는 사용하지 않습니다.

```powershell
godot --headless --path . --editor --import
godot --headless --path . --export-release "Windows Desktop" build/AsteraCraft.exe
```

Windows 내보내기는 Godot 4.6의 Windows x86_64 템플릿을 설치한 뒤 사용하세요. 소스에는 Godot·Node 실행 파일, 빌드 캐시, 로컬 계정 데이터가 포함되지 않습니다. 이 작업 환경용 `tools_run_godot.js`와 패키징 스크립트의 경로는 다른 PC에서 조정해야 합니다.

주요 검증은 `tests/auto_mining_v056_test.gd`, `tests/tera_map_audit_test.gd`, `tests/colony_root_threat_test.gd`, `tests/original_maps_control_test.gd`입니다. Godot에서 `--headless --path . --script tests/이름.gd`로 실행할 수 있습니다. 일부 검사는 `build` 폴더를 먼저 만들어야 합니다.

## 제작 자료와 고지

유닛·건물·지면·메뉴 그림은 이미지 생성으로 제작했으며 효과음과 사망 소리는 합성 제작했습니다. BGM은 사용자 제공 파일입니다. Godot·글꼴의 라이선스 고지는 `licenses`, WebRTC 및 포함 라이브러리 고지는 `addons/webrtc_native/LICENSE.*`에 있습니다. 생성 프롬프트는 `docs/art-prompts-v058*.json`에 보관했습니다.
