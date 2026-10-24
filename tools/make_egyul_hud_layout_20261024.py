from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1];out=root/'work/egyul-hud-common-20261024';out.mkdir(parents=True,exist_ok=True)
canvas=Image.new('RGBA',(1963,330),(0,0,0,0));draw=ImageDraw.Draw(canvas)
draw.rounded_rectangle((0,0,1962,329),radius=24,fill=(102,106,109,255))
holes=[(52,54,292,290),(350,82,1200,290),(1244,34,1430,77),(1253,94,1421,292)]
holes.extend((x-7,y-7,x+93,y+67) for y in [66,150,234] for x in [1490,1600,1710,1820])
for box in holes:draw.rounded_rectangle(box,radius=10,fill=(17,22,25,255))
canvas.save(out/'plain-layout.png')
