"""Read-only contact sheets from the connected runtime atlas, not new sprite art."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/quick_visual23_20261024'
HEADINGS = 'N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW'.split()
FONT = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 18)
SMALL = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 15)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    units = json.loads((ROOT / 'data/art_staged16_units.json').read_text('utf-8'))['units']
    registry = json.loads((ROOT / 'build/staged16_20261023/units.json').read_text('utf-8'))
    names = {f"{u['race']}:{u['id']}": u['name'] for u in registry}
    results = []
    for key, unit in units.items():
        if unit.get('status') != 'applied_unreviewed':
            continue
        actions = unit['actions']
        cache = {}
        pixels = {}
        issues = []
        checked = 0
        for action, clip in actions.items():
            signatures = []
            for index, entry in enumerate(clip.get('frames', [])):
                file = entry.get('file', clip.get('file', unit.get('file')))
                path = ROOT / file.removeprefix('res://')
                if file not in cache:
                    cache[file] = Image.open(path).convert('RGBA')
                atlas = cache[file]
                x, y, w, h = entry['region']
                if x < 0 or y < 0 or x+w > atlas.width or y+h > atlas.height:
                    issues.append({'action': action, 'index': index, 'error': 'out_of_range'})
                tile = atlas.crop((x, y, x+w, y+h))
                alpha = tile.getchannel('A').point(lambda a: 255 if a > 32 else 0)
                b = alpha.getbbox()
                if b is None:
                    issues.append({'action': action, 'index': index, 'error': 'blank'})
                elif b[0] < 2 or b[1] < 2 or b[2] > w-2 or b[3] > h-2:
                    issues.append({'action': action, 'index': index, 'error': 'touches_cell_edge', 'bounds': b})
                pixels[(action, index)] = tile
                signatures.append(hashlib.sha256(tile.tobytes()).hexdigest())
                checked += 1
            # Exact equality is only a flag; stationary/role aliases can be intentional.
            if int(clip.get('rows', 1)) > 1 and action not in ['death', 'morph']:
                cols = int(clip.get('directions', 16))
                frozen = [h for h in range(cols) if len(set(signatures[h::cols])) == 1]
                if frozen:
                    issues.append({'action': action, 'warning': 'all_phases_identical', 'headings': frozen})
        primary = next((a for a in ['attack', 'heal', 'work', 'morph'] if a in actions), None)
        rows = [('idle', 0)]
        rows += [('walk', p) for p in [0, 3, 6]] if 'walk' in actions else []
        rows += [(primary, p) for p in [0, 3, 6]] if primary else []
        rows += [('death', -1)]
        width, cell, row_height = 2240, 140, 156
        sheet = Image.new('RGBA', (width, 74 + row_height*len(rows)), '#20262e')
        draw = ImageDraw.Draw(sheet)
        draw.text((12, 4), f'{key}  {names[key]}  |  CURRENT GAME ATLAS  |  N=BACK / S=FRONT', font=FONT, fill='white')
        for h, heading in enumerate(HEADINGS):
            draw.text((h*cell+8, 41), f'{h:02d} {heading}', font=SMALL, fill='#b7cfe5')
        for row, (action, phase) in enumerate(rows):
            top = 74+row*row_height
            draw.line((0, top, width, top), fill='#46515c')
            draw.text((8, top+2), action+' / '+('0..6' if phase < 0 else str(phase)), font=SMALL, fill='#eac77a')
            clip = actions[action]
            directions = int(clip.get('directions', 16))
            for h in range(7 if phase < 0 else 16):
                idx = h if phase < 0 else min(phase, int(clip.get('rows', 1))-1)*directions+(h if directions>1 else 0)
                tile = pixels.get((action, idx))
                if tile is None:
                    continue
                thumb = tile.resize((140, 140), Image.Resampling.LANCZOS)
                sheet.alpha_composite(thumb, (h*cell, top+14))
                if phase < 0:
                    draw.text((h*cell+7, top+130), f'frame {h}', font=SMALL, fill='#b7cfe5')
        tag = key.replace(':', '_')
        file = OUT / f'{tag}-sheet.png'
        sheet.convert('RGB').save(file)
        results.append({'key': key, 'name': names[key], 'frames_pixel_checked': checked, 'flags': issues, 'sheet': str(file), 'visual_review': 'pending'})
        print(key, names[key], checked, 'flags='+str(len(issues)), flush=True)
        for atlas in cache.values():
            atlas.close()
    (OUT/'pixel-checks.json').write_text(json.dumps({'units': results, 'scope': 'All referenced frame regions/alpha; human visual samples 0/3/6, not every intermediate animation frame.'}, ensure_ascii=False, indent=2), 'utf-8')
    print('DONE', len(results), sum(u['frames_pixel_checked'] for u in results), flush=True)


if __name__ == '__main__':
    main()
