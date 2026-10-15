const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'..','.work','graphics-patch-20261016');
fs.mkdirSync(out,{recursive:true});
const items=['scripts','data','assets/air_registered_v05','assets/construction_v4',
 'assets/air_top_r0_v05.png','assets/air_top_r1_v05.png','assets/air_top_r2_v05.png',
 'assets/medic_repaired_v05.png','assets/medic_registered_v05.png','assets/hyrax_fire_poses_v05.png',
 'assets/owl_buildings_repaired_v05.png','assets/terrain_faces_v05.png','tools_make_construction.gd',
 'tools/register_graphics_repairs_v05.gd','tools/graphics_asset_audit_v05.gd','tools/package_graphics_repairs_v05.cjs',
 'tests/graphics_review_v05.gd','tests/graphics_repairs_v05_test.gd','tests/air_heading_v05_test.gd','tests/terrain_quality_test.gd',
 'docs/graphics_repairs_2026_10_16.json'];
const manifest=[];
function copy(rel){
 const from=path.join(root,rel),to=path.join(out,rel);
 if(fs.statSync(from).isDirectory()){for(const name of fs.readdirSync(from))copy(rel+'/'+name);return;}
 if(/\.(?:import|b64)$/.test(rel))return;
 fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(from,to);
 const bytes=fs.readFileSync(from);manifest.push({file:rel,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
}
items.forEach(copy);
fs.writeFileSync(path.join(out,'MANIFEST.json'),JSON.stringify(manifest,null,2));
fs.writeFileSync(path.join(out,'README.txt'),[
 'AsteraCraft graphics repair source snapshot — 2026-10-16',
 '',
 'This is a source patch for the existing v0.5 working Godot project.',
 'It is not a standalone game or an update installer for a v0.4 EXE.',
 'All changes have already been applied to the current working project.',
 'This archive preserves changed assets, complete current scripts/data, tests and the audit record.',
 'See docs/graphics_repairs_2026_10_16.json for completed fixes and limitations.',
 'Open the working project with Godot 4.6 and let imported images refresh.',
 'Do not merge this snapshot into an older source tree without keeping a backup.',
 ''
].join('\r\n'));
console.log(JSON.stringify({directory:out,files:manifest.length,bytes:manifest.reduce((s,f)=>s+f.bytes,0)}));
