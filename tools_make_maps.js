// Idempotent resource-layout pass. Authored topology, start slots, base pockets,
// catalyst anchors and resource totals remain in data/maps.json unchanged.
const fs=require('node:fs'),path=require('node:path');
const COMPACT_MINERAL_OFFSETS=[[-5.5,-1],[-4.5,-3],[-2.5,-4],[-.5,-4],[1.5,-4],[3.5,-4],[5.5,-3],[6.5,-1]];
function applyCompactMinerals(catalog){
  catalog.mineral_offsets=COMPACT_MINERAL_OFFSETS.map(point=>point.slice());
  catalog.mineral_layout={revision:'0.4-compact',shape:'close_horseshoe_arc',nodes_per_base:8,
    footprint:[2,1],headquarters:[4,3],inner_worker_lane_tiles:3,
    description:'Eight nonoverlapping horizontal minerals form a compact arc around the north edge of each mirrored headquarters pocket; every inner harvesting face stays reachable.'};
  return catalog;
}
module.exports={applyCompactMinerals,COMPACT_MINERAL_OFFSETS};
if(require.main===module){
  const file=path.join(__dirname,'data','maps.json');
  const catalog=applyCompactMinerals(JSON.parse(fs.readFileSync(file,'utf8')));
  fs.writeFileSync(file,JSON.stringify(catalog,null,2)+'\n');
  console.log(JSON.stringify({maps:catalog.maps.length,mineral_offsets:catalog.mineral_offsets,tera_offset:catalog.tera_offset,layout:catalog.mineral_layout},null,2));
}
