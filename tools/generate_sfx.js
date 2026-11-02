#!/usr/bin/env node
// Original synthesized sound cues. No external licensed samples.
const fs=require("fs"),path=require("path");
const dir=path.resolve(__dirname,"../client/assets/sfx");
fs.mkdirSync(dir,{recursive:true});
const rate=22050;
function make(name,seconds,seed,fn) {
  let x=seed>>>0,low=0;
  const size=Math.floor(rate*seconds),buf=Buffer.alloc(44+size*2);
  buf.write("RIFF",0);buf.writeUInt32LE(buf.length-8,4);buf.write("WAVEfmt ",8);
  buf.writeUInt32LE(16,16);buf.writeUInt16LE(1,20);buf.writeUInt16LE(1,22);
  buf.writeUInt32LE(rate,24);buf.writeUInt32LE(rate*2,28);buf.writeUInt16LE(2,32);
  buf.writeUInt16LE(16,34);buf.write("data",36);buf.writeUInt32LE(size*2,40);
  for(let i=0;i<size;i++){
    x^=x<<13;x^=x>>>17;x^=x<<5;const n=(x>>>0)/0x80000000-1;
    low=.84*low+.16*n;
    const t=i/rate;
    const env=Math.min(1,t/.005)*Math.exp(-t/.09)*Math.max(0,1-Math.pow(t/seconds,7));
    const sample=Math.max(-.95,Math.min(.95,fn(t,seconds,n,low,env)));
    buf.writeInt16LE(Math.round(sample*32767),44+i*2);
  }
  fs.writeFileSync(path.join(dir,name),buf);
  console.log(name,buf.length);
}
make("wood_chop.wav",.36,48,(t,d,n,l,e)=>e*(.44*Math.sin(2*Math.PI*(97*t+24*t*t))+.26*l+.28*n*Math.exp(-t/.028)));
make("stone_hit.wav",.34,91,(t,d,n,l,e)=>e*(.33*Math.sin(2*Math.PI*640*t)+.20*Math.sin(2*Math.PI*1120*t)+.34*n*Math.exp(-t/.04)));
make("herb_rustle.wav",.42,208,(t,d,n,l,e)=>(Math.min(1,t/.025)*Math.exp(-t/.175))*(.17*n+.16*l+.14*Math.sin(2*Math.PI*(190+65*t)*t)));
make("build_place.wav",.52,309,(t,d,n,l,e)=>Math.min(1,t/.005)*Math.exp(-t/.23)*(.23*Math.sin(2*Math.PI*350*t)+.17*Math.sin(2*Math.PI*525*t)*(t>.075?1:0)+.13*l));
