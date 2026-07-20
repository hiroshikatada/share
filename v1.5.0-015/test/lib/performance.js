'use strict';
const{performance}=require('node:perf_hooks');
function pct(a,r){const s=[...a].sort((x,y)=>x-y);return s[Math.min(s.length-1,Math.ceil(s.length*r)-1)];}
async function benchmark(fn,n){const t=[];let heap=0,last;for(let i=0;i<n;i++){const h=process.memoryUsage().heapUsed;const st=performance.now();last=await fn();t.push(performance.now()-st);heap=Math.max(heap,Math.max(0,process.memoryUsage().heapUsed-h)/1048576);}return{medianMs:pct(t,.5),p95Ms:pct(t,.95),maxHeapDeltaMb:heap,lastResult:last};}
module.exports={benchmark};
