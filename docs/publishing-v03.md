# v0.3 GitHub 출판

`tools/Publish-AsteraCraft.ps1`는 준비된 도구이며 실제 GitHub 업로드는 실행하지 않았습니다. 전용 공개 저장소 `INTPEDITOR/asteracraft-releases`와 `v0.3`만 사용합니다. 다른 프로젝트 저장소·로컬 Git 기록은 건드리지 않습니다.

GitHub CLI가 없다면 `winget install --id GitHub.cli --exact`로 설치한 뒤 새 PowerShell을 여세요. `gh auth login --hostname github.com --web --git-protocol https`에서 **INTPEDITOR**로 로그인합니다. 토큰을 입력 인수에 넣거나 출력할 필요가 없습니다.

워크스페이스의 `deliverables`에 다음 네 파일을 준비합니다.

- `AsteraCraft-Windows-v0.3.zip`
- `AsteraCraft-Godot-v0.3.zip`
- `SHA256SUMS-v0.3.txt`
- `AsteraCraft-v0.3-review.md`

SHA256SUMS는 `해시  파일이름` 형식이며 두 ZIP과 리뷰 문서의 SHA256을 반드시 포함해야 합니다. 체크섬 파일 자체는 목록에 넣지 않습니다. 다른 목록 항목이 있으면 그 파일들도 모두 검증합니다. 이전 버전으로 대체하지 않습니다.

Godot 프로젝트 폴더에서 실행합니다.

```powershell
# 로컬 파일·해시·로그인·기존 릴리스만 점검. GitHub 변경 없음.
.\tools\Publish-AsteraCraft.ps1 -CheckOnly

# 실제 출판: 전용 저장소가 없으면 생성하고 파일 검증 후 공개 prerelease 발행.
.\tools\Publish-AsteraCraft.ps1
```

E 드라이브 이전 구조도 그대로 지원합니다. `-SourceRoot`에는 프로젝트 자체나 그 상위 작업 폴더를 지정할 수 있습니다.

```powershell
& 'E:\Codex\AsteraCraft\AsteraCraft\tools\Publish-AsteraCraft.ps1' -SourceRoot 'E:\Codex\AsteraCraft'
```

다른 배포 폴더는 `-DeliverablesRoot '절대경로'`, 체크섬·리뷰 파일명이 다르면 `-ChecksumFile '파일명' -ReviewFile '파일명'`을 지정합니다. 파일은 모두 배포 폴더 바로 아래에 있어야 합니다.

새 릴리스는 초안으로 만들고 네 첨부 파일의 실제 크기·SHA256을 검증한 뒤 공개합니다. 조회·업로드·공개는 같은 릴리스 ID에 고정합니다. 노트에는 미검증 네트워크 범위·원본과 대조하지 않은 맵·16방향 모션·미포함 기능·밀집 전투 성능 한계와 리뷰 원문을 포함합니다. **기존 동명 첨부는 해시가 같을 때만 건너뛰며, 다르면 덮어쓰지 않고 중단합니다.** 서버 해시가 없는 첨부는 해당 첨부 ID로 임시 다운로드해 비교합니다. 기존 제목·본문·prerelease 상태가 다르거나 예상하지 않은 첨부가 있어도 자동 수정하지 않습니다. 실패로 남은 동일 초안은 파일을 고치지 않은 상태에서 다시 실행하면 이어서 올릴 수 있습니다. 이미 공개된 릴리스는 네 파일이 모두 일치할 때만 변경 없이 성공 처리합니다.

이 저장소는 배포 전용입니다. Godot 원본은 직접 첨부한 `AsteraCraft-Godot-v0.3.zip`을 받으세요. GitHub가 자동 생성하는 “Source code” ZIP은 게임 프로젝트를 포함하지 않습니다.

명령 기준: [저장소 생성](https://cli.github.com/manual/gh_repo_create), [릴리스 생성](https://cli.github.com/manual/gh_release_create), [첨부 업로드](https://cli.github.com/manual/gh_release_upload), [첨부 다운로드](https://cli.github.com/manual/gh_release_download).
