import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
plan = json.loads((root / 'docs/melee-balance-20261025.json').read_text(encoding='utf-8-sig'))
path = root / 'data/game.json'
source = path.read_bytes()
game = json.loads(source)
for item in plan['changes']:
    unit = game['units'][item['race']][item['kind']]
    assert unit['name'] == item['name']
    assert unit['period'] in (item['before'], item['after'])
    unit['period'] = item['after']
description = '껍질발톱 공격 속도50% 증가(공격 간격0.55→약0.37초).'
next(x for x in game['research'] if x['id'] == 'claw_overdrive')['description'] = description
newline = '\r\n' if b'\r\n' in source else '\n'
path.write_bytes((json.dumps(game, ensure_ascii=False, indent=2) + '\n').replace('\n', newline).encode('utf-8'))
path = root / 'docs/passive-research-20261024.json'
source = path.read_bytes()
passives = json.loads(source)
next(x for x in passives['research'] if x['id'] == 'claw_overdrive')['description'] = description
newline = '\r\n' if b'\r\n' in source else '\n'
path.write_bytes((json.dumps(passives, ensure_ascii=False, indent=2) + '\n').replace('\n', newline).encode('utf-8'))
print(json.dumps({'updated_melee': len(plan['changes']), 'claw_research_period': round(.55 * 2 / 3, 5)}, ensure_ascii=False))
