"""Extract existing owl paintings; write an isolated, review-only race catalog.

No mirrored directions, invented poses, new roles, or accepted-catalog writes.
Solid ivory feathers/armour register scale independently of red attack glows.
"""
from review_radial_headings_20261023 import *
import argparse

SRC=ROOT/'assets/staged16_20261023/race2/sources'
DEST=ROOT/'data/art_staged16_race2_drafts.json'
CELL=320
BUILD_ONLY=False

def ivory(im):
    a=np.asarray(im).astype(float);r,g,b,alpha=[a[:,:,i] for i in range(4)]
    mask=(alpha>224)&(r>125)&(g>100)&(b>65)&(r<g*1.65)&(g<b*1.8)
    yy,xx=np.nonzero(mask)
    assert len(xx)>60,'Missing solid ivory torso/hull'
    return len(xx),np.array([xx.mean(),yy.mean()])

def contact(im):
    a=np.asarray(im);yy,xx=np.nonzero(a[:,:,3]>224)
    return float(np.quantile(yy,.997))

def grid(path,expected=56,cols=7,skip=None):
    im=Image.open(path).convert('RGBA');figures=None;threshold=None;partial=None
    for t in [32,128,224,240,248]:
        trial=components(im,t,1500)
        if len(trial)==expected:figures=trial;threshold=t;break
        if BUILD_ONLY and expected==56 and len(trial)==49:partial=(trial,t)
    if figures is None and partial is not None:figures,threshold=partial
    assert figures is not None,(path.name,'body count does not match',expected)
    result={}
    ordered=sorted(figures,key=lambda f:f['center'][1])
    for row in range(math.ceil(len(figures)/cols)):
        group=sorted(ordered[row*cols:(row+1)*cols],key=lambda f:f['center'][0])
        for col,f in enumerate(group):
            if skip and (row,col) in skip:continue
            l,t,r,b=f['bounds']
            if not BUILD_ONLY:assert l>1 and t>1 and r<im.width-1 and b<im.height-1,(path.name,row,col,'solid source touches border',f['bounds'])
            result[(row,col)]={'tile':isolate(im,f),'source':path.relative_to(ROOT).as_posix(),'source_region':f['bounds'],'alpha_threshold':threshold}
    return result

def bases_for(unit,write_qa=True):
    if unit==11:
        repairs=ROOT/'data/art_direction_repairs_20261023.json'
        if repairs.exists():
            entry=json.loads(repairs.read_text(encoding='utf-8-sig')).get('units',{}).get('2:11',{})
            clip=entry.get('actions',{}).get('idle',{})
            if entry.get('status')=='accepted_direction_repair' and clip.get('file'):
                sheet=Image.open(ROOT/clip['file'].removeprefix('res://')).convert('RGBA')
                tiles=[]
                for heading in range(16):
                    frame=clip.get('frames',[{}]*16)[heading]
                    region=frame.get('region',[heading*sheet.width//16,0,sheet.width//16,sheet.height])
                    x,y,w,h=map(int,region);tile=sheet.crop((x,y,x+w,y+h))
                    tiles.append(tile.crop(tile.getchannel('A').getbbox()))
                return tiles
    out=QA/'canonical'/f'r2_u{unit:02d}'
    if len(list(out.glob('*.png')))==16:
        return [Image.open(out/f'{i:02d}_{n}.png').convert('RGBA') for i,n in enumerate(NAMES)]
    im=Image.open(SRC/f'u{unit:02d}_base16_circular_v1.png').convert('RGBA')
    for threshold in [32,128,224,240,248]:
        figures=components(im,threshold,1500)
        if len(figures)!=16:continue
        for f in figures:
            x,y=f['center'];f['slot']=round((math.atan2((x-im.width/2)/im.width,(im.height/2-y)/im.height)%(2*math.pi))/(math.pi/8))%16
        if sorted(f['slot'] for f in figures)!=list(range(16)):continue
        tiles=[isolate(im,f) for f in sorted(figures,key=lambda f:f['slot'])]
        if write_qa:
            out.mkdir(parents=True,exist_ok=True)
            for i,tile in enumerate(tiles):tile.save(out/f'{i:02d}_{NAMES[i]}.png')
        return tiles
    if unit in range(14):
        # The old ring contains only fourteen drawings. The sixteen first
        # walking poses are already independently painted at all headings.
        # Reuse their neutral stance as idle, without inventing directions.
        tiles=[]
        for start in [0,4,8,12]:
            source=SRC/f'u{unit:02d}_motion_pair_quartet{start:02d}_v1.png'
            if unit==2:source=SRC/f'u02_motion_quartet{start:02d}_direction_fixed_v2.png'
            pieces=grid(source,49 if unit==4 and start==12 else 56)
            tiles.extend(pieces[(row,0)]['tile'] for row in range(4))
        if write_qa:
            out.mkdir(parents=True,exist_ok=True)
            for i,tile in enumerate(tiles):tile.save(out/f'{i:02d}_{NAMES[i]}.png')
        return tiles
    raise AssertionError(('base needs local repair',unit))

def pack(unit,no_qa=False,reuse_existing=False):
    global BUILD_ONLY
    BUILD_ONLY=no_qa
    if reuse_existing and DEST.exists() and f'2:{unit}' in json.loads(DEST.read_text())['units']:
        return {'unit':unit,'reused_existing':True}
    tag=f'u{unit:02d}';out=ROOT/f'assets/staged16_20261023/race2/{tag}_motion';out.mkdir(exist_ok=True)
    game=json.loads((ROOT/'data/game.json').read_text(encoding='utf-8-sig'))['units'][2][unit]
    air=game.get('air',False);armed=(game.get('damage',0)>0 or unit==4) and unit not in [6,11]
    bases=bases_for(unit,write_qa=not no_qa);base_scale=205/max(max(im.size) for im in bases)
    base_metrics=[ivory(im) for im in bases]
    anchor=np.array([160.,220. if not air else 160.])
    poses={'idle':{},'walk':{},'attack':{},'death':{}};records=[];unavailable={}
    def place(tile,scale,origin):
        image=tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS)
        if BUILD_ONLY:
            box=image.getbbox();fit=min(1.,296/max(1,box[2]-box[0]),296/max(1,box[3]-box[1]))
            if fit<1:
                scale*=fit
                image=tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS)
        xy=np.rint(anchor-origin*scale).astype(int);box=image.getbbox()
        bounds=np.array(box)+np.array([*xy,*xy]);shift=np.maximum(12-bounds[:2],0)-np.maximum(bounds[2:]-308,0)
        xy+=shift;physical=np.array(box)+np.array([*xy,*xy])
        assert min(physical[:2])>=12 and max(physical[2:])<=308,('packed clip',unit,physical.tolist())
        canvas=Image.new('RGBA',(CELL,CELL));canvas.alpha_composite(image,tuple(xy))
        return canvas,anchor+shift
    for heading,tile in enumerate(bases):
        _,center=base_metrics[heading];origin=center if air else np.array([center[0],contact(tile)])
        poses['idle'][(heading,0)]=place(tile,base_scale,origin)
    for start in [0,4,8,12]:
        source=SRC/f'{tag}_motion_pair_quartet{start:02d}_v1.png'
        if unit==2:source=SRC/f'u02_motion_quartet{start:02d}_direction_fixed_v2.png'
        pieces=grid(source,49 if unit==4 and start==12 else 56)
        if unit==0 and start==4 and (SRC/'u00_SSE_work7_fixed_v2.png').exists():
            fixed=grid(SRC/'u00_SSE_work7_fixed_v2.png',7,7)
            for phase in range(7):pieces[(7,phase)]=fixed[(0,phase)]
        if unit==4 and start==12:
            # The generated final robe touches its image edge. Keep six intact
            # painted healing phases and recover to the genuine old neutral
            # NNW stance, rather than crop or repeat the clipped painting.
            fixed=grid(SRC/'u04_NNW_heal7_fixed_v2.png',7,7,{(0,6)})
            fixed[(0,6)]=pieces[(3,0)]
            for phase in range(7):pieces[(7,phase)]=fixed[(0,phase)]
        for local in range(4):
            heading=start+local
            for action,row in [('walk',local),('attack',4+local)]:
                if action=='attack' and not armed:continue
                if BUILD_ONLY and any((row,p) not in pieces for p in range(7)):
                    unavailable.setdefault(action,[]).append(heading)
                    continue
                metrics=[ivory(pieces[(row,p)]['tile']) for p in range(7)]
                scales={}
                for phase in range(7):
                    source=pieces[(row,phase)]['source']
                    group=[metrics[p][0] for p in range(7) if pieces[(row,p)]['source']==source]
                    scales[source]=base_scale*math.sqrt(base_metrics[heading][0]/float(np.median(group)))
                for phase in range(7):
                    record=pieces[(row,phase)];tile=record['tile'];center=metrics[phase][1]
                    scale=scales[record['source']]
                    origin=center if air else np.array([center[0],contact(tile)])
                    poses[action][(heading,phase)]=place(tile,scale,origin)
                    records.append({'action':action,'heading':heading,'phase':phase,'scale':scale,**{k:v for k,v in record.items() if k!='tile'}})
    death=grid(SRC/f'{tag}_death7_v1.png',7,4)
    area,_=ivory(death[(0,0)]['tile']);scale=base_scale*math.sqrt(base_metrics[6][0]/area)
    for phase in range(7):
        record=death[(phase//4,phase%4)];tile=record['tile'];_,center=ivory(tile)
        origin=center if air else np.array([center[0],contact(tile)])
        poses['death'][(0,phase)]=place(tile,scale,origin)
        records.append({'action':'death','heading':0,'phase':phase,'scale':scale,**{k:v for k,v in record.items() if k!='tile'}})
    definition={'status':'review','directions':16,'full_circle':True,'staged16':True,'scale_hint':200,'anchor':anchor.tolist(),'actions':{},'provenance':{'original_files_preserved':True,'new_roles_added':False,'excluded_visuals':['hangar','cargo_ramp','lens','scan','decorative_idle'],'review_scope':'extraction_and_source_geometry_only_pending_native_game_review'}}
    summary=[]
    for action,dirs,rows,fps,loop in [('idle',16,1,1,True),('walk',16,7,9,True),('attack',16,7,14,False),('death',1,7,9,False)]:
        if action=='attack' and not armed:continue
        atlas=Image.new('RGBA',(CELL*dirs,CELL*rows));frames=[];hashes=set()
        for phase in range(rows):
            for heading in range(dirs):
                if (heading,phase) not in poses[action]:
                    frames.append({})
                    continue
                canvas,pivot=poses[action][(heading,phase)];box=canvas.getbbox();atlas.alpha_composite(canvas,(heading*CELL,phase*CELL))
                frames.append({'region':[heading*CELL,phase*CELL,CELL,CELL],'bounds':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'anchor':pivot.tolist()})
                if not no_qa:hashes.add(hashlib.sha256(canvas.tobytes()).hexdigest())
        if not no_qa:assert len(hashes)==dirs*rows,(unit,action,'duplicate authored poses',len(hashes))
        path=out/f'{action}.png';atlas.save(path)
        definition['actions'][action]={'file':'res://'+path.relative_to(ROOT).as_posix(),'columns':dirs,'directions':dirs,'rows':rows,'fps':fps,'loop':loop,'frames':frames}
        definition['actions'][action]['authored_frames']=sum(bool(f) for f in frames)
        if unavailable.get(action):definition['actions'][action]['unavailable_headings']=sorted(unavailable[action])
        summary.append({'action':action,'frames':sum(bool(f) for f in frames),'slots':len(frames)})
        if not no_qa and action in ['walk','attack']:
            page=Image.new('RGBA',(2240,1280),'#20262e')
            for row,h in enumerate([0,4,8,12]):
                for phase in range(7):page.alpha_composite(poses[action][(h,phase)][0],(phase*320,row*320))
            page.save(QA/f'r2_{tag}-{action}-cardinals.png')
    if unit==0:
        definition['actions']['work']=dict(definition['actions']['attack']);definition['actions']['work']['loop']=True
    if unit==4 and 'attack' in definition['actions']:
        definition['actions']['heal']=dict(definition['actions']['attack']);definition['actions']['heal']['loop']=True
    if not no_qa:review([poses['idle'][(h,0)][0] for h in range(16)],QA/f'r2_{tag}-packed16-review.png',f'OWL {unit} / OUTWARD16')
    if no_qa:definition['provenance']['review_scope']='existing_source_packing_only_user_requested_no_additional_review'
    definition['metadata']={'authored_attack_frames':definition['actions'].get('attack',{}).get('authored_frames',0)}
    if unavailable:
        definition['provenance']['limitations']=[{'action':a,'unavailable_headings':sorted(hs),'missing_authored_frames':len(hs)*7,'fallback':'Root sampler displays the existing exact-heading idle; no fabricated attack pose.'} for a,hs in unavailable.items()]
    catalog=json.loads(DEST.read_text()) if DEST.exists() else {'schema':1,'units':{}}
    catalog['units'][f'2:{unit}']=definition;DEST.write_text(json.dumps(catalog,indent=2)+'\n')
    if not no_qa:(QA/f'r2_{tag}-packing.json').write_text(json.dumps({'status':'review_only_not_integrated','actions':summary,'provenance':records},indent=2)+'\n')
    return {'unit':unit,'logical_frames':sum(x['frames'] for x in summary),'actions':summary}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--unit',type=int);p.add_argument('--all-missing',action='store_true');p.add_argument('--no-qa',action='store_true');args=p.parse_args()
    if args.all_missing:
        for unit in range(14):
            try:print(json.dumps(pack(unit,no_qa=args.no_qa,reuse_existing=True)),flush=True)
            except Exception as exc:print(json.dumps({'unit':unit,'packing_error':repr(exc)}),flush=True)
    elif args.unit is not None:print(json.dumps(pack(args.unit,no_qa=args.no_qa)))
    else:p.error('--unit or --all-missing is required')
