const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const locked=JSON.parse(fs.readFileSync(path.join(root,'build/locked-graphics-v052.json'),'utf8').replace(/^\uFEFF/,''));
for(const entry of locked)assert.equal(hash(entry.Path),entry.Hash.toLowerCase());
const before=fs.readFileSync(path.join(root,'build/before-original-maps/rts_hud.gd'),'utf8').replaceAll('\r',''),after=fs.readFileSync(path.join(root,'scripts/rts_hud.gd'),'utf8').replaceAll('\r','');
const methods=['_layout','shell_draw_rect','shell_rect','_shell_geometry','_single_menu_source','_portrait_rect','command_slot_rect','minimap_rect'];
function method(s,name){const start=s.indexOf('func '+name+'(');assert(start>=0);const next=s.indexOf('\nfunc ',start+1);return s.slice(start,next<0?s.length:next).trim()}
for(const name of methods)assert.equal(method(after,name),method(before,name),name);
const report={passed:true,airAssetsUnchanged:locked.length,hudGeometryMethodsUnchanged:methods,portraitChange:'contain full image within existing frame; no frame resize'};
fs.writeFileSync(path.join(root,'build/visual-locks-v053.json'),JSON.stringify(report,null,2));console.log(report);
