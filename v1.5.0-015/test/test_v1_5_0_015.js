'use strict';
const fs=require('node:fs');const path=require('node:path');
const{Reporter}=require('./lib/reporter');const{loadEngine}=require('./lib/engine_adapter');
const{collectSqlMetrics,collectResultMetrics,verifyContract}=require('./lib/metrics');
const{compareGolden}=require('./lib/golden');const{benchmark}=require('./lib/performance');
const ROOT=path.resolve(__dirname,'..');
async function main(){
 const reporter=new Reporter('BigQuery Physical Lineage Engine v1.5.0-015 | Boss SQL Stress Test');reporter.header();
 const sql=fs.readFileSync(path.join(ROOT,'sql/boss_customer_sales_mart.sql'),'utf8');
 const metadata=JSON.parse(fs.readFileSync(path.join(ROOT,'fixtures/information_schema_columns.json'),'utf8'));
 const contract=JSON.parse(fs.readFileSync(path.join(__dirname,'contracts/performance_contract_v1_5_0_015.json'),'utf8'));
 const engine=loadEngine();
 reporter.section(1,4,'Parser / Engine');reporter.pass(engine.connected?`Engine: ${engine.modulePath}`:'Static validation mode');
 const sm=collectSqlMetrics(sql,engine.tokenize);reporter.pass('Boss SQL loaded');
 let result={},rm=collectResultMetrics(result),perf=null;
 if(engine.connected){perf=await benchmark(()=>engine.analyze(sql,metadata),contract.iterations);result=perf.lastResult;rm=collectResultMetrics(result);reporter.pass('Lexer / Parser / Scope / Physical lineage completed');}
 reporter.section(2,4,'Golden');
 if(engine.connected){const g=compareGolden(result,path.join(ROOT,'expected/boss_customer_sales_mart_expected.json'),process.env.UPDATE_GOLDEN==='1');g.passed?reporter.pass(g.updated?'Golden updated':'Golden PASS'):reporter.fail('Golden FAILED',g.detail);}else reporter.pass('Golden skipped; set LINEAGE_ENGINE_MODULE');
 reporter.section(3,4,'Stress Metrics');
 for(const[n,v]of Object.entries({"SQL Lines":sm.sqlLines,"Tokens":sm.tokenCount,"CTE Count":sm.cteCount,"JOIN Count":sm.joinCount,"LEFT JOIN Count":sm.leftJoinCount,"UNION ALL":sm.unionAllCount,"PIVOT":sm.pivotCount,"UNNEST":sm.unnestCount,"CASE":sm.caseCount}))reporter.metric(n,v);
 if(engine.connected){reporter.metric('AST Nodes',rm.astNodes??'N/A');reporter.metric('Scope Depth',rm.scopeDepth);reporter.metric('Dependency Depth',rm.dependencyDepth);reporter.metric('Output Columns',rm.outputColumns);reporter.metric('Median',perf.medianMs.toFixed(3),' ms');reporter.metric('P95',perf.p95Ms.toFixed(3),' ms');reporter.metric('Max Heap Delta',perf.maxHeapDeltaMb.toFixed(3),' MB');}
 reporter.section(4,4,'Regression Contract');const failures=verifyContract(sm,rm,contract,engine.connected);
 if(engine.connected){if(perf.medianMs>contract.maxMedianMs)failures.push('Median performance limit exceeded');if(perf.p95Ms>contract.maxP95Ms)failures.push('P95 performance limit exceeded');if(perf.maxHeapDeltaMb>contract.maxHeapDeltaMb)failures.push('Heap limit exceeded');}
 failures.length?failures.forEach(x=>reporter.fail('Regression FAILED',x)):reporter.pass('Regression PASS');
 const report={test:'test_v1_5_0_015',status:reporter.failures.length?'FAIL':'PASS',mode:engine.connected?'ENGINE':'STATIC',engineModule:engine.modulePath,sqlMetrics:sm,resultMetrics:rm,performance:perf?{medianMs:perf.medianMs,p95Ms:perf.p95Ms,maxHeapDeltaMb:perf.maxHeapDeltaMb}:null,failures:reporter.failures};
 fs.writeFileSync(path.join(ROOT,'output/test_v1_5_0_015_result.json'),JSON.stringify(report,null,2)+'\n');reporter.finish();process.exitCode=reporter.failures.length?1:0;
}
main().catch(e=>{console.error(e.stack||e.message);process.exitCode=1;});
