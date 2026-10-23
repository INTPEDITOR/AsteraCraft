"""Decode loading-art drafts, preserve provenance, and make review-only contact sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/loading_art_review_20261024'
FONT = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 21)
SMALL = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 16)
NAMES = ['바위너구리', '귤', '부엉이']

def main():
    latest = {}
    decisions_file = WORK / 'decisions.json'
    decisions = json.loads(decisions_file.read_text(encoding='utf-8-sig')) if decisions_file.exists() else {}
    approval_file = ROOT / 'docs/loading-art-approval-20261024.json'
    if approval_file.exists():
        explicit_approval = json.loads(approval_file.read_text(encoding='utf-8-sig'))
        decisions['approved'] = sorted(set(decisions.get('approved', [])) | set(explicit_approval.get('approved_ids', [])))
    for file in (WORK / 'records').glob('story-*.json'):
        item = json.loads(file.read_text(encoding='utf-8-sig'))
        if not item.get('preview') or item.get('status') in ('rejected', 'excluded') or item['id'] in decisions.get('rejected', {}):
            continue
        match = re.fullmatch(r'story-r([012])-(\d+)-v(\d+)', item['id'])
        if not match:
            continue
        race, number, version = map(int, match.groups())
        key = (race, number)
        if key not in latest or version > latest[key][0]:
            latest[key] = (version, item)
    report = []
    for race in range(3):
        page = Image.new('RGB', (1280, 2040), '#10171c')
        draw = ImageDraw.Draw(page)
        approved_race = all((race, number) in latest and latest[(race, number)][1]['id'] in decisions.get('approved', []) for number in range(1, 11))
        draw.text((18, 8), NAMES[race] + (' · 적용 승인 완료' if approved_race else ' · 적용 승인 전 시안'), font=FONT, fill='white')
        for number in range(1, 11):
            if (race, number) not in latest:
                continue
            item = latest[(race, number)][1]
            path = Path(item['preview'])
            with Image.open(path) as image:
                image.load()
                width, height = image.size
                if width < 1200 or height < 675:
                    raise ValueError(f'Insufficient preview size: {path}')
                thumb = image.convert('RGB')
                thumb.thumbnail((632, 356), Image.Resampling.LANCZOS)
            col, row = (number - 1) % 2, (number - 1) // 2
            x, y = col * 640 + 4, 46 + row * 398
            page.paste(thumb, (x, y))
            title = item.get('title') or {0: '길을 여는 전차와 돌격병', 1: '부상 중갑수 치료', 2: '빔 엄호와 측면 공격'}[race]
            draw.text((x + 4, y + 357), f'{number:02d}  {title}', font=SMALL, fill='#e3e7e9')
            units = list(item.get('units', []))
            for ref in item.get('refs', []):
                match = re.search(r'r([012])_u(\d+)\.png$', ref)
                if match:
                    unit = ':'.join(map(str, map(int, match.groups())))
                    if unit not in units:
                        units.append(unit)
            report.append({
                'id': item['id'], 'race': race, 'number': number, 'title': title,
                'units': units, 'source': item['source'], 'preview': str(path),
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'width': width, 'height': height, 'approved': item['id'] in decisions.get('approved', []),
                'status': 'user_approved' if item['id'] in decisions.get('approved', []) else 'draft_pending_user_integration_approval',
                'prompt_record': str(WORK / 'records' / (item['id'] + '.json')),
                'prompt': item['prompt'],
                'references': item.get('refs', []),
            })
        page.save(WORK / f'review-race{race}.jpg', quality=94, subsampling=0)
    catalog_file = ROOT / 'data/loading_art_20261024.json'
    catalog = json.loads(catalog_file.read_text(encoding='utf-8')) if catalog_file.exists() else {'images': []}
    registered = sum(bool(item.get('approved', False)) for item in catalog['images'])
    result = {'mode': 'builtin_image_gen', 'images': report, 'counts': [sum(i['race'] == race for i in report) for race in range(3)], 'registered': registered}
    (WORK / 'review-manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    if result['counts'] == [10, 10, 10] and registered == 30 and all(item['approved'] for item in report):
        for item in report:
            entry = next(value for value in catalog['images'] if value['id'] == item['id'])
            item['game_file'] = entry['file']
        (ROOT / 'docs/loading-art-final-review-20261024.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'counts': result['counts'], 'registered': registered, 'decoded': len(report)}))

if __name__ == '__main__':
    main()
