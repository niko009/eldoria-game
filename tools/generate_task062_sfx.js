// Deterministic original procedural audio placeholders for Eldoria.
// No recordings, third-party samples or proprietary audio are used here.
const fs = require('fs');
const path = require('path');
const outDir = path.join(__dirname,'../client/assets/sfx');
const rate = 22050;
let seed = 0x5eed9;
function random(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/0x100000000;}
const defs={
 bow_twang: {seconds:0.34, synth(t,T){const env=Math.exp(-13*t/T);return env*(0.55*Math.sin(2*Math.PI*(155*t+21*t*t))+0.22*Math.sin(2*Math.PI*320*t)+0.20*(random()*2-1))*Math.sin(Math.PI*Math.min(t*700,0.5));}},
 wolf_snarl: {seconds:0.64, synth(t,T){const env=Math.sin(Math.PI*t/T)**0.65;let pitch=57-20*t/T+7*Math.sin(2*Math.PI*7*t);return env*(0.52*Math.sin(2*Math.PI*pitch*t)+0.16*Math.sin(2*Math.PI*2*pitch*t)+0.2*(random()*2-1)*Math.sin(2*Math.PI*18*t))*0.85;}},
 wolf_death: {seconds:0.76, synth(t,T){const env=Math.sin(Math.PI*t/T)*Math.exp(-1.6*t/T);let pitch=165-110*t/T;return env*(0.54*Math.sin(2*Math.PI*pitch*t)+0.22*Math.sin(2*Math.PI*2*pitch*t)+0.14*(random()*2-1));}},
 mage_heal: {seconds:0.74,synth(t,T){const env=Math.sin(Math.PI*t/T)**1.25;const phase=2*Math.PI*(400*t+200*t*t);return env*(0.36*Math.sin(phase)+0.26*Math.sin(phase*1.25)+0.17*Math.sin(2*Math.PI*711*t)+0.1*(random()*2-1))*0.9;}},
 rogue_dash: {seconds:0.30,synth(t,T){const env=Math.exp(-5*t/T);const osc=Math.sin(2*Math.PI*(230*t+110*t*t));return env*(0.58*(random()*2-1)+0.27*osc);}},
 knight_taunt: {seconds:0.62,synth(t,T){const env=(1-Math.exp(-85*t))*Math.exp(-3*t/T);return env*(0.56*Math.sin(2*Math.PI*(115*t-25*t*t))+0.3*Math.sin(2*Math.PI*228*t)+0.14*(random()*2-1));}}
};
function writeWav(name,def){const size=Math.ceil(def.seconds*rate);const wave=Buffer.alloc(44+size*2);wave.write('RIFF',0);wave.writeUInt32LE(wave.length-8,4);wave.write('WAVEfmt ',8);wave.writeUInt32LE(16,16);wave.writeUInt16LE(1,20);wave.writeUInt16LE(1,22);wave.writeUInt32LE(rate,24);wave.writeUInt32LE(rate*2,28);wave.writeUInt16LE(2,32);wave.writeUInt16LE(16,34);wave.write('data',36);wave.writeUInt32LE(size*2,40);let lp=0;for(let i=0;i<size;i++){const t=i/rate, raw=def.synth(t,def.seconds);lp=lp*0.64+raw*0.36;const fade=Math.min(1,t/0.006,(def.seconds-t)/0.021);wave.writeInt16LE(Math.round(Math.max(-1,Math.min(1,lp*0.68*Math.max(0,fade)))*30000),44+2*i);}const dest=path.join(outDir,name+'.wav');fs.writeFileSync(dest,wave);console.log(name,wave.length,'bytes');}
for(const [name,def] of Object.entries(defs))writeWav(name,def);
