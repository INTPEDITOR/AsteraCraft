"""Register only the ten Citrus images explicitly approved by the user.

This helper handles only Citrus. Other factions require their own recorded
approval and the separate faction-registration helper.
"""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/loading_art_review_20261024'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    approval = json.loads((ROOT / 'docs/loading-art-approval-20261024.json').read_text(encoding='utf-8-sig'))
    approved = {value for value in approval['approved_ids'] if value.startswith('story-r1-')}
    if approval['user_approved_faction']['race'] != 1 or len(approved) != 10 or any(not value.startswith('story-r1-') for value in approved):
        raise ValueError('This helper requires exactly ten approved Citrus race1 IDs')
    manifest = json.loads((WORK / 'review-manifest.json').read_text(encoding='utf-8'))
    selected = sorted((item for item in manifest['images'] if item['race'] == 1), key=lambda item: item['number'])
    if len(selected) != 10 or {item['id'] for item in selected} != approved:
        raise ValueError('The current Citrus selection must exactly match user approval')
    output = ROOT / 'assets/loading_art_20261024/race1'
    output.mkdir(parents=True, exist_ok=True)
    catalog_file = ROOT / 'data/loading_art_20261024.json'
    catalog = json.loads(catalog_file.read_text(encoding='utf-8')) if catalog_file.exists() else {'images': []}
    images = [item for item in catalog['images'] if item['race'] != 1]
    for item in selected:
        source = Path(item['preview'])
        if digest(source) != item['sha256']:
            raise ValueError('Reviewed Citrus art changed: ' + item['id'])
        target = output / (item['id'] + '.png')
        if target.exists() and digest(target) != item['sha256']:
            raise ValueError('Refusing to overwrite different artwork: ' + str(target))
        if not target.exists():
            shutil.copyfile(source, target)
        images.append({'id': item['id'], 'race': 1, 'file': 'res://assets/loading_art_20261024/race1/' + target.name, 'approved': True, 'sha256': item['sha256'], 'title': item['title'], 'units': item['units']})
    catalog['images'] = sorted(images, key=lambda item: (item['race'], item['id']))
    catalog['approval_rule'] = 'Only explicit user integration approval permits registration.'
    catalog_file.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'registered_faction': 'Citrus', 'race': 1, 'count': 10, 'hyrax_registered_by_this_operation': 0, 'owl_registered_by_this_operation': 0}))

if __name__ == '__main__':
    main()
