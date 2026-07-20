'use strict';
class Reporter {
  constructor(title){this.title=title;this.failures=[];}
  header(){console.log('='.repeat(61));console.log(' '+this.title);console.log('='.repeat(61));}
  section(i,n,name){console.log(`\n[${i}/${n}] ${name}`);}
  pass(name){console.log(`  ✓ ${name}`);}
  fail(name,detail){console.log(`  ✗ ${name}`);if(detail)console.log(`    ${detail}`);this.failures.push({name,detail});}
  metric(name,value,suffix=''){console.log(`  ${name.padEnd(28)}: ${value}${suffix}`);}
  finish(){console.log('\n'+'='.repeat(61));console.log(this.failures.length?' TEST FAILED':' ALL TESTS PASSED');console.log('='.repeat(61));}
}
module.exports={Reporter};
