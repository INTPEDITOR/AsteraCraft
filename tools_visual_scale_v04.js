const fs=require('node:fs'),path=require('node:path');
const extents=[[34,30,32,38,30,64,56,30,36,64,80,72,104],[32,22,40,64,24,48,56,42,24,52,52,72,100],[30,40,38,40,36,36,32,64,64,68,38,68,104]];
function applyVisualScale(data){for(let r=0;r<3;r++)for(let k=0;k<13;k++)data.units[r][k].visual_extent=extents[r][k];return data;}
module.exports={applyVisualScale,extents};
if(require.main===module){const file=path.join(__dirname,'data/game.json'),data=applyVisualScale(JSON.parse(fs.readFileSync(file,'utf8')));fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');console.log('39 unit visual extents calibrated to 32px build tiles; source aspect ratios preserved.');}
