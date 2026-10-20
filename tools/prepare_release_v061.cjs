const fs=require('fs');
for(const [source,target] of [
 ['tests/release_v060_pack_test.gd','tests/release_v061_pack_test.gd'],
 ['tools/run_release_v060_checks.cjs','tools/run_release_v061_checks.cjs'],
 ['tools/publish_v060.cjs','tools/publish_v061.cjs'],
 ['tools/public_p2p_v058_test.cjs','tools/public_p2p_v061_test.cjs']]){
 if(fs.existsSync(target))continue;
 let text=fs.readFileSync(source,'utf8').replaceAll('0.6.0','0.6.1').replaceAll('v060','v061').replaceAll('V060','V061');
 if(source.includes('pack_test'))text=text.replaceAll('industrial_units_v061.json','industrial_units_v060.json').replaceAll('audio/manifest_v061.json','audio/manifest_v060.json');
 if(source.includes('p2p'))text=text.replaceAll("'X-Astera-Protocol':'10'","'X-Astera-Protocol':'11'").replaceAll('release-v058','release-v061').replaceAll('p2p-release-v058','p2p-release-v061').replaceAll('p2p-source-v058','p2p-source-v061');
 if(source.includes('pack_test'))text=text.replace('int(network.protocol)==10','int(network.protocol)==11').replace('protocol ten for observer host and closed slots','protocol eleven for continuous area damage and visible-ground collision').replace('check(original.visual_role(44*128+57)==3,"reported flat doodad remains an obstacle in the release")','check(original.source_ground_fits(Vector2(.2,.2),Vector2(57,44)),"invisible doodad collision removed in the release")').replace('var game=JSON.parse_string','check(FileAccess.file_exists("res://data/siege_layers_v061.json") and FileAccess.file_exists("res://data/flame_stream_v061.json"),"layered transformation and continuous flame bundled")\n\tvar game=JSON.parse_string').replace('root.add_child(main);main.set_anchors','check(not main.REPLAYS_ENABLED,"replay recording disabled in release")\n\troot.add_child(main);main.set_anchors');
 fs.writeFileSync(target,text);
}
const preset='export_presets.cfg';let config=fs.readFileSync(preset,'utf8');if(!config.includes('assets/*_v061_source.png'))config=config.replace('exclude_filter="','exclude_filter="assets/*_v061_source.png,');fs.writeFileSync(preset,config);
console.log('Prepared v061 release checks, publisher, P2P test and source-art exclusion');
