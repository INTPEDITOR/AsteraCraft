"""Exercise the Windows updater's real exported-game startup handshake."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import time

root = Path(__file__).resolve().parents[1]
out = root / 'build/updater-e2e-20261024'
game = out / 'game'
appdata = out / 'appdata'
state = appdata / 'Godot/app_userdata/아스테라크래프트/updates/state.json'
old = root / 'build/feedback2_20261024'
new = root / 'build/feedback3_20261024'
archive = new / 'AsteraCraft-Windows-feedback3-20261024.zip'
names = ['AsteraCraft.exe', 'AsteraCraft.pck', 'libwebrtc_native.windows.template_release.x86_64.dll']
checks = 0

def check(value, label):
    global checks
    checks += 1
    if not value:
        raise AssertionError(label)

def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

check(game.resolve().is_relative_to(out.resolve()), 'test installation is workspace-local')
game.mkdir(parents=True, exist_ok=True)
appdata.mkdir(parents=True, exist_ok=True)
for name in names:
    shutil.copyfile(old / name, game / name)
(game / 'settings.keep').write_text('keep user settings', encoding='utf-8')
helper = out / 'apply-update.ps1'
helper.write_bytes((root / 'data/windows_updater.txt').read_bytes())
env = dict(os.environ, APPDATA=str(appdata))
args = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', str(helper), '-GameDirectory', str(game), '-Archive', str(archive),
        '-ArchiveSha256', digest(archive), '-Tag', 'feedback3-20261024', '-StateFile', str(state)]
started = time.monotonic()
process = subprocess.run(args, env=env, capture_output=True, timeout=240, creationflags=0x08000000)
(out / 'helper-stdout.txt').write_bytes(process.stdout)
(out / 'helper-stderr.txt').write_bytes(process.stderr)
# Only this disposable fixture's process may be closed by the test.
quoted = str(game / 'AsteraCraft.exe').replace("'", "''")
stop = "$p=@(Get-Process -Name AsteraCraft -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq '" + quoted + "'}); $p | ForEach-Object {Stop-Process -Id $_.Id -Force}; $p | Select-Object -ExpandProperty Id"
closed = subprocess.run(['powershell.exe', '-NoProfile', '-Command', stop], capture_output=True,
                        creationflags=0x08000000, timeout=15)
check(process.returncode == 0, 'helper completed real install and startup: ' + process.stderr.decode('cp949', errors='replace')[-1000:])
record = json.loads(state.read_text(encoding='utf-8-sig'))
check(record['phase'] == 'confirmed' and record['tag'] == 'feedback3-20261024', 'exported game confirmed its packed version')
for name in names:
    check(digest(game / name) == digest(new / name), 'current payload matches final export: ' + name)
    check(digest(game / '.asteracraft-update-backup' / name) == digest(old / name), 'previous payload retained: ' + name)
check((game / 'settings.keep').read_text() == 'keep user settings', 'unrelated user data preserved')
check(closed.returncode == 0 and bool(closed.stdout.strip()), 'only fixture game was located and closed')
result = {'passed': True, 'checks': checks, 'elapsed_seconds': round(time.monotonic() - started, 2),
          'phase': record['phase'], 'tag': record['tag'],
          'scope': 'Actual Windows helper replaces a disposable feedback2 installation with the final feedback3 ZIP, launches its real EXE, receives startup confirmation from the packed version, preserves previous files and unrelated data. No user installation is modified.'}
(out / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
