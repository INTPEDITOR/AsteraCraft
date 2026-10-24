from pathlib import Path
import json, shutil, subprocess

root = Path(__file__).resolve().parents[1]
out = root / 'build/feedback7_20261024'
qa = root / 'docs/verification_feedback7_20261024'
checks = {}
for name, source in {
    'pack': out / 'pack-result.json',
    'windows-startup': out / 'exe-smoke.json',
    'archive': out / 'package-result.json',
    'update-install': root / 'build/updater-feedback7-e2e-20261024/result.json',
}.items():
    data = json.loads(source.read_text(encoding='utf-8'))
    assert data['passed'], (name, data)
    shutil.copyfile(source, qa / (name + '.json'))
    checks[name] = data
source = json.loads((qa / 'source-validation.json').read_text(encoding='utf-8'))
assert source['passed']
result = {'passed': True, 'source': source['checks'], 'exports': checks}
(qa / 'exports.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
if '--committed' in __import__('sys').argv:
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    package = checks['archive']
    validation = {
        'passed': True, 'commit': sha,
        'camera_geometry_checks': source['checks']['camera-geometry']['checks'],
        'camera_pixel_screens': source['checks']['camera-screens']['checks'],
        'air_hover_checks': source['checks']['air-hover']['checks'],
        'air_unit_count': 12, 'native_image_count': 12,
        'actual_update_checks': checks['update-install']['checks'],
        'sha256': package['sha256'], 'bytes': package['bytes'],
        'validation': 'docs/verification_feedback7_20261024/exports.json',
    }
    (out / 'release-validation.json').write_text(json.dumps(validation, indent=2), encoding='utf-8')
print('FEEDBACK7_EXPORTS_VERIFIED', json.dumps({'passed': True, 'package_bytes': checks['archive']['bytes']}))
