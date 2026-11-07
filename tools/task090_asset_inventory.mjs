#!/usr/bin/env node
// Reproducible source-asset and procedural UI inventory. Does not modify the game.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root = path.resolve(import.meta.dirname, '..');
const client = path.join(root, 'client');
const output = path.join(root, 'docs/audits/task090_asset_inventory.csv');
const formats = new Set(['.gltf','.glb','.png','.jpg','.jpeg','.ogg','.wav']);
const sourceExt = new Set(['.gd','.tscn','.tres','.godot']);
const provenance = {
  nature:['CC0 Quaternius','client/assets/nature/License_Standard.txt'],
  characters:['CC0 KayKit','client/assets/characters/LICENSE.txt'],
  wildlife:['CC0 claimed per model','client/assets/wildlife/LICENSE_SOURCES.md'],
  terrain:['Generated for Eldoria','client/assets/terrain/PROVENANCE.md'],
  sfx:['Mixed Kenney CC0 / generated; verify per file','client/assets/sfx/TASK062_LICENSE_SOURCES.md']
};
const walk = (dir) => fs.readdirSync(dir,{withFileTypes:true}).flatMap(e => {
  if (e.name === '.godot' || e.name === 'tests') return [];
  const full = path.join(dir,e.name);
  return e.isDirectory() ? walk(full) : [full];
});
const rel = p => path.relative(root,p).replaceAll(path.sep,'/');
const source = walk(client).filter(p=>sourceExt.has(path.extname(p))).map(p=>[rel(p),fs.readFileSync(p,'utf8')]);
const sha = data=>crypto.createHash('sha256').update(data).digest('hex');
const rows=[];
for (const p of walk(path.join(client,'assets')).filter(p=>formats.has(path.extname(p))).sort()){
  const id=rel(p), family=id.split('/')[2], data=fs.readFileSync(p);
  const refs=source.filter(([,text])=>text.includes(id.slice(7))||text.includes(path.basename(p))).map(([name])=>name);
  rows.push([id,family,path.extname(p),data.length,sha(data),refs.slice(0,8).join('; ')||'NOT_FOUND_IN_STATIC_SOURCE',
    ...(provenance[family]||['UNKNOWN','']), 'NOT_CAPTURED','NOT_VISUALLY_REVIEWED','NOT_MEASURED','NOT_SELECTED',
    'Verify source license and visual appearance before replacement']);
}
for(const f of ['client/ui/item_icon.gd','client/ui/tool_icon.gd']){
  const text=fs.readFileSync(path.join(root,f),'utf8');
  const keys=[...new Set([...text.matchAll(/^\s*"([a-z_]+)":\s*$/gm)].map(m=>m[1]))].sort();
  for(const key of keys)rows.push(['procedural:'+f+':'+key,'ui','GDScript draw',0,sha(f+':'+key),f,
    'Project-authored; verify repository rights',f,'NOT_CAPTURED','NOT_VISUALLY_REVIEWED','N/A','NOT_SELECTED',
    'Small mobile silhouette requires visual comparison']);
}
const headers=['asset_id','family','format','bytes','sha256','referenced_by','license_claim','license_evidence','screenshot','readability','triangles_draw_calls','candidate','risk'];
const csv = cell=>'"'+String(cell).replaceAll('"','""')+'"';
fs.mkdirSync(path.dirname(output),{recursive:true});
fs.writeFileSync(output,[headers,...rows].map(row=>row.map(csv).join(',')).join('\n')+'\n');
console.log('TASK090 INVENTORY PASS:',rows.length,'records;',source.length,'source files');
