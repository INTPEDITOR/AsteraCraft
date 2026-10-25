"""Collect local source-only evidence; never export, upload or publish."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(path):
    return json.loads((root / path).read_text(encoding='utf-8-sig'))
def write(path, value):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def head(path):
    return subprocess.check_output(['git', 'show', f'HEAD:{path}'], cwd=root).decode('utf-8')

plan = read('docs/melee-balance-20261025.json')
game = read('data/game.json')
previous = json.loads(head('data/game.json'))
expected = json.loads(json.dumps(previous))
for item in plan['changes']:
    assert previous['units'][item['race']][item['kind']]['period'] == item['before']
    expected['units'][item['race']][item['kind']]['period'] = item['after']
expected['units'][1][11]['visual_extent'] = 72
description = '껍질발톱 공격 속도50% 증가(공격 간격0.55→약0.37초).'
next(x for x in expected['research'] if x['id'] == 'claw_overdrive')['description'] = description
assert game == expected, 'Unexpected gameplay data changes outside seven periods, approved transport size and research description'
assert (root/'scripts/core.gd').read_text(encoding='utf-8-sig') == head('scripts/core.gd'), 'Combat/advanced-AI core must stay unchanged'
assert read('docs/ai-tactics-review-20261025.json')['status'] == 'awaiting_user_review_not_implemented'

results = {
    'melee_cadence_and_battles': read('build/melee-balance-20261025/result.json'),
    'contact': read('build/move-attack-followup-20261025/melee-scenarios.json'),
    'research': read('build/passives-20261024/result.json'),
    'pursuit': read('build/player_colors_20261024/melee.json'),
    'stim': read('build/stim-20261024/result.json'),
}
for name, result in results.items():
    assert not result['failures'], (name, result['failures'])
duels = results['melee_cadence_and_battles']['battles']
assert len(duels) == 48
for duel in duels:
    assert all(duel['attacked']) and all(duel['travelled'])
    assert all(0 <= n <= count for n, count in zip(duel['remaining'], duel['counts'])), 'Technical brood pods must not count as combat soldiers'
    assert sum(duel['health']) < sum(duel['initial_health']), 'Every duel must inflict real damage'

known = []
for name, before_path, after_path in [
    ('combat_test', 'build/melee-balance-legacy-combat-before.txt', 'build/melee-balance-combat-console.txt'),
    ('abilities_v060_test', 'build/melee-balance-legacy-abilities-before.txt', 'build/melee-balance-abilities-console.txt'),
]:
    def failures(path):
        return [line for line in (root/path).read_text(encoding='utf-8-sig').splitlines() if re.match(r'^FAIL(?: |:)', line)]
    before = failures(before_path)
    after = failures(after_path)
    assert before == after, (name, before, after)
    known.append({'test': name, 'before': before, 'after': after, 'unchanged_from_before': True})

summary = []
for before in [x for x in duels if x['phase'] == 'before']:
    after = next(x for x in duels if x['phase'] == 'after' and x['case'] == before['case'] and x['reverse'] == before['reverse'])
    summary.append({'case': before['case'], 'reverse': before['reverse'], 'counts': before['counts'], 'remaining_before': before['remaining'], 'remaining_after': after['remaining'], 'health_before': before['health'], 'health_after': after['health'], 'seconds_before': before['seconds'], 'seconds_after': after['seconds']})

report = {
    'status': 'source_locally_verified_not_released',
    'version': game['version'],
    'game_sha256': hashlib.sha256((root/'data/game.json').read_bytes()).hexdigest(),
    'changes': [{**item, 'nominal_attack_speed_gain_percent': round((item['before']/item['after']-1)*100, 2)} for item in plan['changes']],
    'approved_transport_extent': 72,
    'advanced_ai': 'Not implemented; 30 concrete tactics await user review.',
    'checks': sum(x['checks'] for x in results.values()),
    'focused_checks_passed': True,
    'focused_suites': {name: {'checks': x['checks'], 'failures': x['failures']} for name, x in results.items()},
    'cadence_cases': len(results['melee_cadence_and_battles']['cadences']),
    'real_field_battles': len(duels),
    'duel_comparison': summary,
    'known_test_failures_reproduced_before_change': known,
    'limits': ['Equal-resource open-field comparisons and mechanic regression only; not final competitive balance or win-rate proof.', 'No Windows export, packaging, updater or public release performed for these changes.'],
}
write('docs/verification_melee_balance_20261025/checks.json', report)
plan['status'] = 'implemented_and_locally_verified_not_released'
plan['verification'] = 'docs/verification_melee_balance_20261025/checks.json'
write('docs/melee-balance-20261025.json', plan)
print(json.dumps({'focused_checks': report['checks'], 'field_battles': len(duels), 'cadence_cases': report['cadence_cases'], 'known_unchanged_failures': sum(len(x['before']) for x in known)}, ensure_ascii=False))
