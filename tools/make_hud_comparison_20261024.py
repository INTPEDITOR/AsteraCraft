from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1];out=root/'build/feedback4-20261024'
images=[Image.open(out/f'common-hud-r{race}-strip.png').convert('RGB') for race in range(3)]
canvas=Image.new('RGB',(max(im.width for im in images),sum(im.height+25 for im in images)),(20,25,29));draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype(str(root/'assets/fonts/LevelUp-Regular.ttf'),16);y=0
for caption,image in zip(['노바너','이귤 적용 화면','아라아울'],images):
    draw.text((6,y+4),caption,font=font,fill='white');canvas.paste(image,(0,y+25));y+=image.height+25
canvas.save(out/'hud-common-comparison.png')
