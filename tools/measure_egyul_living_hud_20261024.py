from pathlib import Path
from PIL import Image
import numpy as np,json,shutil
root=Path(__file__).resolve().parents[1];out=root/'work/egyul-hud-common-20261024'
source=Path(r'C:\Users\Admin\.codex\generated_images\01a1658f-18eb-7781-929a-256a0df7e051\exec-84e977e9-a58a-4208-88b7-481008a7b225.png')
shutil.copyfile(source,out/'living-v2.png')
a=np.asarray(Image.open(source).convert('RGBA'));rgb=a[:,:,:3].astype(int)
dark=(a[:,:,3]>240)&(rgb.max(axis=2)<50)&(rgb.max(axis=2)-rgb.min(axis=2)<12)
result={}
for x in [170,190,750,1470,1640]:
    bits=dark[:,x];edges=np.diff(np.r_[False,bits,False].astype(int));starts=np.where(edges==1)[0];ends=np.where(edges==-1)[0]
    result[x]=sorted([[int(s),int(e)] for s,e in zip(starts,ends) if e-s>10],key=lambda v:v[1]-v[0],reverse=True)
print(json.dumps(result))
