#!/usr/bin/env node
// Isolated internal test API: no database, no production secrets.
const http=require('node:http'),fs=require('node:fs');
const output=process.env.ELDORIA_MOCK_LOG;
const key='task018-telemetry-test-local-only-key';
let revision=0;
http.createServer((req,res)=>{
  if(req.headers['x-eldoria-server-key']!==key){res.writeHead(401);res.end();return;}
  const finish=(status,object)=>{
    res.writeHead(status,{'Content-Type':'application/json'});
    res.end(JSON.stringify(object));
  };
  if(req.method==='GET'&&req.url==='/v1/world/20261101'){
    finish(200,{schema:1,world_seed:20261101,revision,depleted:{},profiles:{},buildings:{}});
    return;
  }
  if(req.method==='POST'&&req.url==='/v1/telemetry'){
    let raw='';
    req.on('data',part=>{raw+=part.toString();if(raw.length>4096)req.destroy();});
    req.on('end',()=>{
      const data=JSON.parse(raw);
      fs.appendFileSync(output,JSON.stringify(data)+'\n');
      finish(202,{});
    });
    return;
  }
  finish(404,{error:'not_found'});
}).listen(19091,'127.0.0.1',()=>console.log('MOCK TELEMETRY API READY'));
