'use strict';
const fs=require('node:fs');const path=require('node:path');
function loadEngine(){
 const candidates=[process.env.LINEAGE_ENGINE_MODULE,path.resolve(process.cwd(),'src/index.js'),path.resolve(process.cwd(),'src/lineage_engine.js'),path.resolve(process.cwd(),'lineage_engine.js')].filter(Boolean);
 for(const candidate of candidates){
  if(!fs.existsSync(candidate))continue;
  const engine=require(candidate);const analyze=engine.analyzeSql||engine.analyze||engine.parseAndResolve||engine.run;
  if(typeof analyze!=='function')throw new TypeError(`No supported analyze function exported by ${candidate}`);
  return{connected:true,modulePath:candidate,tokenize:typeof engine.tokenize==='function'?engine.tokenize:null,analyze:(sql,metadata)=>analyze(sql,metadata)};
 }
 return{connected:false,modulePath:null,tokenize:null,analyze:null};
}
module.exports={loadEngine};
