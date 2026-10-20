const sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
(async()=>{for(let race=0;race<3;race++){
 const {data,info}=await sharp(`assets/ui_hud_${race}_complete_v060.png`).ensureAlpha().raw().toBuffer({resolveWithObject:true}),seen=new Uint8Array(info.width*info.height),results=[];
 const dark=p=>data[p*4+3]>240&&Math.max(data[p*4],data[p*4+1],data[p*4+2])<68;
 for(let p=0;p<seen.length;p++){if(seen[p]||!dark(p))continue;let q=[p],n=0,l=info.width,t=info.height,r=0,b=0;seen[p]=1;for(let head=0;head<q.length;head++){const z=q[head],x=z%info.width,y=Math.floor(z/info.width);n++;l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);for(const v of [z-1,z+1,z-info.width,z+info.width])if(v>=0&&v<seen.length&&!seen[v]&&Math.abs(v%info.width-x)+Math.abs(Math.floor(v/info.width)-y)===1&&dark(v)){seen[v]=1;q.push(v);}}if(n>1800)results.push([l,t,r-l+1,b-t+1,n]);}
 console.log(race,JSON.stringify(results));
 }})();
