// Offline, deterministic effects: no shared bus tails can leak between speakers.
const RATE=24000;
function filter(x,cutoff,high=false){
 const a=1-Math.exp(-2*Math.PI*cutoff/RATE),y=new Float32Array(x.length);let low=0;
 for(let i=0;i<x.length;i++){low+=a*(x[i]-low);y[i]=high?x[i]-low:low}return y;
}
function processVoice(x,c){
 const notice=!!c.announcer,wet=notice?.65:1;
 if(c.race===0){
  const band=filter(filter(x,300,true),3400),lead=notice?0:Math.round(RATE*.018),tail=Math.round(RATE*(notice?.035:.065));
  const y=new Float32Array(x.length+lead+tail);let seed=719+(c.kind||0)*37;
  for(let i=0;i<x.length;i++){
   seed=(Math.imul(seed,1664525)+1013904223)>>>0;
   const grit=(seed/2147483648-1)*Math.min(.006,Math.abs(band[i])*.025)*wet;
   y[i+lead]=x[i]*(notice?.25:.12)+Math.tanh(band[i]*1.65)/1.65*.88+grit;
  }
  // Brief squelch at transmission boundaries, never a continuous noise bed.
  if(!notice)for(let j=0;j<Math.round(RATE*.012);j++){
   const t=j/RATE,e=Math.sin(Math.PI*j/(RATE*.012))**2;
   y[j]+=.027*e*Math.sin(2*Math.PI*1500*t);
   y[x.length+lead+j]+=.022*e*Math.sin(2*Math.PI*1100*t);
  }
  return y;
 }
 const hive=c.race===1,tail=notice?.16:(hive?.21:.29),y=new Float32Array(x.length+Math.ceil(RATE*tail));
 const colored=filter(x,hive?1800:4800),taps=hive?[[.026,.15],[.057,.11],[.123,.065],[.196,.025]]:[[.071,.17],[.139,.10],[.223,.045],[.281,.018]];
 y.set(x);
 for(const [delay,gain] of taps){const offset=Math.round(delay*RATE);for(let i=0;i<colored.length&&i+offset<y.length;i++)y[i+offset]+=colored[i]*gain*wet;}
 if(hive){
  // Slowly detuned delayed layers retain consonants in the untouched main voice.
  for(let i=0;i<x.length;i++){
   const p=i-RATE*(.018+.0025*Math.sin(2*Math.PI*.8*i/RATE)),j=Math.floor(p);
   if(j>=0)y[i]+=(colored[j]*(1-(p-j))+colored[j+1]*(p-j))*.12*wet;
  }
 }
 return y;
}
module.exports={processVoice,RATE};
