'use strict';
const fs=require('node:fs');
function canonicalize(v){if(Array.isArray(v))return v.map(canonicalize).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));if(v&&typeof v==='object'){const o={};for(const k of Object.keys(v).sort()){if(['elapsed_ms','analyzed_at','analysis_id'].includes(k))continue;o[k]=canonicalize(v[k]);}return o;}return v;}
function compareGolden(actual,path,update){const a=canonicalize(actual);const e=JSON.parse(fs.readFileSync(path,'utf8'));if(update||!e.generated){fs.writeFileSync(path,JSON.stringify({format_version:'1.0',case_name:'boss_customer_sales_mart',generated:true,canonical_result:a},null,2)+'\n');return{passed:true,updated:true};}return{passed:JSON.stringify(e.canonical_result)===JSON.stringify(a),updated:false,detail:'Actual result differs from Golden JSON.'};}
module.exports={compareGolden};
