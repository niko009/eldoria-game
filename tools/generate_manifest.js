#!/usr/bin/env node
// Generate a release manifest only from built artifacts, never from guessed hashes.
const fs=require("fs"), crypto=require("crypto"), path=require("path");
const version=process.argv[2];
if(!/^\d{1,4}\.\d{1,4}\.\d{1,4}$/.test(version||""))throw Error("Provide a semver (e.g. 0.2.0)");
const root=path.resolve(__dirname,"..");
function artifact(filename){
 const content=fs.readFileSync(path.join(root,"builds",filename));
 return {url:"https://bacus.dev/projects/eldoria/"+filename,sha256:crypto.createHash("sha256").update(content).digest("hex"),bytes:content.length};
}
const manifest={
 schema:1,version,
 notes:"Новый лес Eldoria, обновления Windows и Android.",
 windows:artifact("Eldoria-Windows-"+version+".zip"),
 android:artifact("Eldoria-"+version+"-debug.apk")
};
fs.writeFileSync(path.join(root,"builds","latest.json"),JSON.stringify(manifest,null,2)+"\n");
console.log(JSON.stringify(manifest,null,2));
