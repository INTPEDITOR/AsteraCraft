const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'..');
function edit(file,fn){const p=path.join(root,file);fs.writeFileSync(p,fn(fs.readFileSync(p,'utf8')))}
edit('project.godot',s=>s.replace('config/version="0.5.2"','config/version="0.5.3"'));
edit('data/game.json',s=>{let d=JSON.parse(s);d.version='0.5.3';return JSON.stringify(d,null,2)+'\n'});
edit('server/server.js',s=>s.replace("VERSION='0.4.0'","VERSION='0.5.3'").replaceAll('protocol:4','protocol:5').replaceAll('ASTERA_DISCOVER_V4','ASTERA_DISCOVER_V5'));
edit('scripts/lobby_discovery.gd',s=>s.replaceAll('ASTERA_DISCOVER_V4','ASTERA_DISCOVER_V5').replace('response.get("protocol",0))==4','response.get("protocol",0))==5'));
edit('scripts/menu_pages.gd',s=>s.replace('data.get("protocol",0))!=4','data.get("protocol",0))!=5'));
edit('scripts/main.gd',s=>s.replace('"version":"0.5.2"','"version":"0.5.3"'));
for(const [src,dst] of [['tools/run_release_v052_checks.cjs','tools/run_release_v053_checks.cjs'],['tests/release_v052_pack_test.gd','tests/release_v053_pack_test.gd'],['tests/bot_v051_test.gd','tests/bot_v053_test.gd'],['tools/archive_release_v052.ps1','tools/archive_release_v053.ps1']]){
 let s=fs.readFileSync(path.join(root,src),'utf8');s=s.replaceAll('v052','v053').replaceAll('V052','V053').replaceAll('0.5.2','0.5.3');if(src.includes('bot'))s=s.replaceAll('v051','v053').replaceAll('V051','V053');
 if(src.includes('pack_test'))s=s.replace('graphics_v053.json','graphics_v052.json').replace('death_v053.json','death_v052.json');
 fs.writeFileSync(path.join(root,dst),s);
}
fs.mkdirSync(path.join(root,'build/release-v053'),{recursive:true});
