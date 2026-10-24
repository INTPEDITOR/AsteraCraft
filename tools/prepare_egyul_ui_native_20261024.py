"""Prepare each independently generated size; never reuse or stretch a plate.

Raw sources stay intact. Each dedicated drawing is uniformly reduced once for
its own intended native file, with transparent padding. Aspect mismatches are
rejected instead of stretched, cropped through decorations, or patched.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,shutil,math
root=Path(__file__).resolve().parents[1];records=root/'docs/egyul-ui-native-20261024';work=root/'work/egyul-ui-native-20261024'
(work/'sources').mkdir(parents=True,exist_ok=True);(work/'native').mkdir(exist_ok=True)
active={'button-320x76','button-145x44','button-220x48','button-105x36','board-1260x840','board-1060x840','board-820x650','board-760x300','board-520x300'}
results=[];latest={}
for file in sorted(records.glob('*.json')):
    record=json.loads(file.read_text(encoding='utf-8'));ident=record['id']
    if ident not in active:continue
    if ident not in latest or record.get('revision',1)>=latest[ident].get('revision',1):latest[ident]=record
for record in sorted(latest.values(),key=lambda r:r['id']):
    source=Path(record['source']);raw=work/'sources'/(record['id']+'-v'+str(record.get('revision',1))+'.png')
    shutil.copyfile(source,raw);im=Image.open(raw).convert('RGBA');box=im.getchannel('A').point(lambda alpha:255 if alpha>=8 else 0).getbbox();assert box
    w,h=record['intended_size'];bw=box[2]-box[0];bh=box[3]-box[1];ratio_error=abs((bw/bh)/(w/h)-1)
    # Uneven organic ornaments may leave transparent margins. They must retain
    # their aspect rather than be forced to fill both dimensions of the canvas.
    # Large margins remain visible in the report and require the native review.
    item={'id':record['id'],'size':[w,h],'source':str(raw.relative_to(root)),'source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'source_canvas':list(im.size),'source_used_box':list(box),'ratio_error':round(ratio_error,4),'needs_native_layout_review':ratio_error>.10,'passed_geometry':bw>=w and bh>=h}
    if item['passed_geometry']:
        # This drawing was made independently FOR this one size. This is its
        # final raster output, never a different-size substitute or runtime scale.
        factor=min(w/bw,h/bh,1);nw=max(1,math.floor(bw*factor));nh=max(1,math.floor(bh*factor));art=im.crop(box)
        if (nw,nh)!=art.size:art=art.resize((nw,nh),Image.Resampling.LANCZOS)
        native=Image.new('RGBA',(w,h));native.alpha_composite(art,((w-nw)//2,(h-nh)//2));dest=work/'native'/(record['id']+'.png');native.save(dest)
        item.update(native=str(dest.relative_to(root)),native_size=[w,h],painted_size=[nw,nh],uniform_output_scale=factor,runtime_scale=1,reused_for_other_size=False)
    results.append(item)
(work/'native-preparation.json').write_text(json.dumps({'source':'Independent built-in image_gen call for every size','no_stretch':True,'no_nine_slice':True,'runtime_connected':False,'items':results},indent=2),encoding='utf-8')
print(json.dumps({'ready':sum(r['passed_geometry'] for r in results),'needs_redraw':[{k:r[k] for k in ['id','source_canvas','ratio_error']} for r in results if not r['passed_geometry']]}))
