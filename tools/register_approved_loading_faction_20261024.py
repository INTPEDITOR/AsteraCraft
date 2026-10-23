"""Register a faction only when its current ten IDs match recorded human approval."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/loading_art_review_20261024'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--race', type=int, choices=(0, 2), required=True)
    args = parser.parse_args()
    approval = json.loads((ROOT / 'docs/loading-art-approval-20261024.json').read_text(encoding='utf-8-sig'))
    faction = next((item for item in approval.get('approved_factions', []) if item['race'] == args.race), None)
    if faction is None or not faction.get('user_quote'):
        raise ValueError('No explicit human approval for this faction')
    approved = set(faction['ids'])
    if len(approved) != 10 or any(not item.startswith(f'story-r{args.race}-') for item in approved):
        raise ValueError('Approval must name ten images of this exact faction')
    manifest = json.loads((WORK / 'review-manifest.json').read_text(encoding='utf-8'))
    selected = [item for item in manifest['images'] if item['race'] == args.race]
    if len(selected) != 10 or {item['id'] for item in selected} != approved:
        raise ValueError('Current selected images differ from human approval')
    catalog_file = ROOT / 'data/loading_art_20261024.json'
    catalog = json.loads(catalog_file.read_text(encoding='utf-8'))
    images = [item for item in catalog['images'] if item['race'] != args.race]
    output = ROOT / f'assets/loading_art_20261024/race{args.race}'
    output.mkdir(parents=True, exist_ok=True)
    for item in selected:
        source = Path(item['preview'])
        if digest(source) != item['sha256']:
            raise ValueError('Reviewed artwork changed: ' + item['id'])
        target = output / (item['id'] + '.png')
        if target.exists() and digest(target) != item['sha256']:
            raise ValueError('Refusing to overwrite different artwork')
        if not target.exists():
            shutil.copyfile(source, target)
        images.append({'id': item['id'], 'race': args.race, 'file': 'res://assets/loading_art_20261024/race%d/%s' % (args.race, target.name), 'approved': True, 'sha256': item['sha256'], 'title': item['title'], 'units': item['units']})
    catalog['images'] = sorted(images, key=lambda item: (item['race'], item['id']))
    catalog_file.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'registered_race': args.race, 'count': 10, 'catalog_total': len(images)}))

if __name__ == '__main__':
    main()
