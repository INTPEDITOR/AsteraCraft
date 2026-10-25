"""Restore original 3/3 starts; never move any original resource or terrain."""
from pathlib import Path
import json,hashlib,math,sys
root=Path(__file__).resolve().parents[1];path=root/'data/original_maps.json';catalog=json.loads(path.read_text(encoding='utf-8'))
def box(pos,size):return (pos[0]-size[0]/2,pos[1]-size[1]/2,pos[0]+size[0]/2,pos[1]+size[1]/2)
def hq(p):return (p[0]-.5,p[1]-.5,p[0]+3.5,p[1]+2.5)
def gap(a,b):return max(a[0]-b[2],b[0]-a[2],a[1]-b[3],b[1]-a[3])
def surface(m,p,level):
 x,y=p
 return x>=0 and y>=0 and x+4<=128 and y+3<=128 and all(m['buildable_map'][yy*128+xx] and m['height_map'][yy*128+xx]==level for yy in range(y,y+3) for xx in range(x,x+4))
plan={'schema':1,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'headquarters_size':[4,3],'mineral_gap':3,'tera_gap':3,'policy':'Original CHK starting headquarters anchors and ALL original resources/terrain unchanged. Three-tile edge clearance to As and Tera/refineries. Prefer exact 3/3 expansion anchors; report source terrain exceptions.','maps':[]};blocked=[]
for i,m in enumerate(catalog['maps']):
 starts=[[math.floor(p[0]-2),math.floor(p[1]-1.5)] for p in m['starts']];sites=[]
 nodes=[(n,box(n['pos'],n['collision_size'])) for n in m['resources'] if n['type']!='as' or n['amount']>0]
 for bid,b in enumerate(m['bases']):
  local=[n for n in m['resources'] if n['id'] in b['resources']];ore=[n for n in local if n['type']=='as' and n['amount']>=500];vents=[n for n in local if n['type']=='tera']
  if len(ore)<3:continue
  sx,sy=b['pos'];level=m['height_map'][int(sy)*128+int(sx)]
  anchors=[starts[b['slot']]] if b['main'] else [[x,y] for y in range(max(0,int(sy)-18),min(126,int(sy)+18)) for x in range(max(0,int(sx)-18),min(125,int(sx)+18))]
  choices=[]
  for p in anchors:
   if not surface(m,p,level):continue
   rect=hq(p)
   if any(gap(rect,body)<3 for n,body in nodes if n['type']!='as' or n['amount']>1):continue
   asgap=min(gap(rect,box(n['pos'],[2,1])) for n in ore);gasgap=min((gap(rect,box(n['pos'],[4,2])) for n in vents),default=3)
   avg=sum((n['pos'][0]-min(max(n['pos'][0],rect[0]),rect[2]))**2+(n['pos'][1]-min(max(n['pos'][1],rect[1]),rect[3]))**2 for n in ore)/len(ore)
   choices.append(((asgap-3)*1000000+(gasgap-3)*100000+avg,p,asgap,gasgap))
  if not choices:
   blocked.append({'map':i,'base':bid,'position':b['pos'],'access':b['access']});continue
  _,p,asgap,gasgap=min(choices)
  if b['main']:assert asgap==gasgap==3,(i,bid,asgap,gasgap)
  clearing=[n['id'] for n,body in nodes if n['type']=='as' and n['amount']==1 and gap(hq(p),body)<3]
  sites.append({'base':bid,'kind':b['kind'],'access':b['access'],'slot':b['slot'],'headquarters_anchor':p,'mineral_gap':asgap,'tera_gap':gasgap if vents else None,'tera_id':vents[0]['id'] if vents else None,'requires_mining':clearing})
 plan['maps'].append({'id':i,'name':m['name'],'source':m['source'],'source_sha256':m['source_sha256'],'starting_headquarters_anchors':starts,'tera_overrides':[],'base_sites':sites})
 print(json.dumps({'map':i,'bases':len(sites),'exceptions':[s for s in sites if s['mineral_gap']!=3 or s['tera_gap'] not in [3,None]]},ensure_ascii=False))
print('BLOCKED_3_CLEARANCE',json.dumps(blocked,ensure_ascii=False))
assert '--apply' not in sys.argv or not blocked,'Unresolved source terrain exceptions cannot be applied'
output=root/('data/resource_spacing_20261025.json' if '--apply' in sys.argv else 'build/resource-spacing-3-plan.json')
output.write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('RESOURCE_3_PLAN',output)
