#!/usr/bin/env node
// TASK-069 isolated mock. Never connects to production/PostgreSQL.
const http=require('node:http');
const schema=1,world_seed=20261101;
const itemNames=['wood','stone','herb','axe','bandage','repair_kit','spear','bow','shield','arrow','meat','hide','bone','leather_armor','grilled_meat'];
let state={schema,world_seed,revision:0,profiles:{},depleted:{},buildings:{}};
let puts=0,gets=0;
http.createServer((req,res)=>{
  const reply=(status,obj)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(obj));};
  if(req.headers['x-eldoria-server-key']!=='task069-internal-only-test-secret')return reply(401,{error:'unauthorized'});
  if(req.url!='/v1/world/20261101')return reply(404,{});
  if(req.method==='GET'){
    gets++;
    if(gets===1)return reply(503,{error:'transient_unavailable'});
    return reply(200,state);
  }
  if(req.method!=='PUT')return reply(405,{});
  let body='';req.on('data',s=>body+=s);req.on('end',()=>{
    const requested=JSON.parse(body);
    puts++;
    if(requested.revision!==state.revision)return reply(409,{error:'stale_world_revision',revision:state.revision});
    if(puts===3){
      // Simulate another writer. The client MUST NOT treat this as a valid ack.
      state={...state,revision:state.revision+1,depleted:{'35':0}};
      return reply(409,{error:'stale_world_revision',revision:state.revision});
    }
    const profiles={};
    for(const [key,profile] of Object.entries(requested.profiles)){
      const inv=Object.fromEntries(itemNames.map(i=>[i,profile.inventory[i]||0]));
      profiles[key]={avatar:profile.avatar,inventory:inv,skills:profile.skills||{archery:0,spear:0,defense:0}};
    }
    state={...requested,profiles,revision:state.revision+1};
    if(puts===1)return reply(409,{error:'simulated_lost_ack',revision:state.revision});
    return reply(200,{revision:state.revision});
  });
}).listen(19093,'127.0.0.1',()=>console.log('TASK069 MOCK READY'));
