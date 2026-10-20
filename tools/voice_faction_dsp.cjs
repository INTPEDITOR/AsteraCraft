// Offline, deterministic effects: no shared bus tails can leak between speakers.
const RATE=24000;
function filter(x,cutoff,high=false){
 const a=1-Math.exp(-2*Math.PI*cutoff/RATE),y=new Float32Array(x.length);let low=0;
 for(let i=0;i<x.length;i++){low+=a*(x[i]-low);y[i]=high?x[i]-low:low}return y;
}
function processVoice(x,c){
 const notice=!!c.announcer,wet=1;
 if(c.race===0){
  const k=Number(c.kind||0),band=filter(filter(x,300+(k%4)*45,true),2050+(k%5)*190),lead=Math.round(RATE*.065),tail=Math.round(RATE*.14);
  const y=new Float32Array(x.length+lead+tail);let seed=719+(c.kind||0)*37;
  for(let i=0;i<x.length;i++){
   seed=(Math.imul(seed,1664525)+1013904223)>>>0;
   const grit=(seed/2147483648-1)*Math.min(.025,Math.abs(band[i])*.14)*wet;
   const clipped=Math.round(Math.tanh(band[i]*5)*48)/48;
   y[i+lead]=x[i]*.015+clipped*.63+grit;
  }
  // Brief squelch at transmission boundaries, never a continuous noise bed.
  for(let j=0;j<Math.round(RATE*.035);j++){
   seed=(Math.imul(seed,1664525)+1013904223)>>>0;
   const t=j/RATE,e=Math.sin(Math.PI*j/(RATE*.035))**2,n=seed/2147483648-1;
   y[j]+=.17*e*(Math.sin(2*Math.PI*1750*t)*.35+n*.65);
   y[x.length+lead+j]+=.15*e*(Math.sin(2*Math.PI*1250*t)*.25+n*.75);
  }
  return y;
 }
 const hive=c.race===1,tail=hive?.43:.72,y=new Float32Array(x.length+Math.ceil(RATE*tail));
 const colored=filter(x,hive?2400:4200),taps=hive?[[.045,.30],[.095,.22],[.19,.17],[.32,.09],[.41,.03]]:[[.06,.26],[.12,.30],[.22,.22],[.34,.15],[.48,.08],[.62,.04]];
 for(let i=0;i<x.length;i++)y[i]=x[i]*(hive?.78:.86);
 for(const [delay,gain] of taps){const offset=Math.round(delay*RATE);for(let i=0;i<colored.length&&i+offset<y.length;i++)y[i+offset]+=colored[i]*gain*wet;}
 if(!hive){
  // Two moving resonant layers behind the intelligible stone oracle voice.
  // Each unit keeps its own depth; this is not a shared delay bus.
  const identity=Number(c.kind||0),depth=.003+(identity%5)*.0004;
  for(let i=0;i<x.length;i++)for(const [delay,phase,gain] of [[.021,0,.30],[.037,2.2,.22]]){
   const p=i-RATE*(delay+depth*Math.sin(2*Math.PI*(.43+identity*.013)*i/RATE+phase)),j=Math.floor(p);
   if(j>=0&&j+1<colored.length)y[i]+=(colored[j]*(1-(p-j))+colored[j+1]*(p-j))*gain;
  }
 }
 if(hive){
  // Slowly detuned delayed layers retain consonants in the untouched main voice.
  for(let i=0;i<x.length;i++){
   const p=i-RATE*(.024+.006*Math.sin(2*Math.PI*.7*i/RATE)),j=Math.floor(p);
   if(j>=0)y[i]+=(colored[j]*(1-(p-j))+colored[j+1]*(p-j))*.36*wet;
  }
 }
 return y;
}
module.exports={processVoice,RATE};
