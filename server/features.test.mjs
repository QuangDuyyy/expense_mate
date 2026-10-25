import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createAiServer,categories} from './server.mjs';
import {validateReceipt,isoDate} from './receipt.mjs';
import {summaryFacts,validateInsights} from './insights.mjs';
const token='test-token-for-feature-tests-1234567890';
const empty=()=>({value:null,evidence:''});
const receipt={merchant:{value:'CA PHE AN',evidence:'CA PHE AN'},date:{value:'2026-10-25',evidence:'Ngày 25/10/2026'},amount:{value:65000,evidence:'THÀNH TIỀN PHẢI TRẢ 65.000'},warnings:[]};
const raw='CA PHE AN\nNgày 25/10/2026\nTHÀNH TIỀN PHẢI TRẢ 65.000';
const summary={period:'month',totals:[65000,35000,0,0,0,0],previousTotals:[50000,0,0,0,0,0],count:2,previousCount:1,observedDays:25,comparisonDays:25,budget:3000000};
async function run(response,work){
 let outbound;
 const server=createAiServer({apiKey:'fake',token,fetchImpl:async(url,opts)=>{
  outbound=JSON.parse(opts.body);return Response.json({candidates:[{content:{parts:[{text:JSON.stringify(response)}]}}]});
 }});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{await work(`http://127.0.0.1:${server.address().port}`,()=>outbound);}
 finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
}
const post=(url,path,body,key=token)=>fetch(url+path,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${key}`},body:JSON.stringify(body)});
test('receipt preserves only values grounded in original text',()=>{
 const r=validateReceipt(receipt,raw);assert.equal(r.amount.value,65000);assert.equal(r.date.value,'2026-10-25');assert.equal(r.merchant.value,'CA PHE AN');assert.equal(r.needsReview,true);
});
test('hallucinated evidence and values are removed',()=>{
 const r=validateReceipt({...receipt,amount:{value:99000,evidence:'TOTAL 99.000'},merchant:{value:'NEW SHOP',evidence:'CA PHE AN'}},raw);
 assert.equal(r.amount.value,null);assert.equal(r.merchant.value,null);assert(r.warnings.length>=2);
});
test('decimal money and cash/change cannot validate a total',()=>{
 for(const evidence of ['TOTAL 65.000,50','Tiền khách đưa 65.000','Tiền thừa 65.000','TOTAL -65000']){
  const r=validateReceipt({merchant:empty(),date:empty(),amount:{value:65000,evidence},warnings:[]},evidence);
  assert.equal(r.amount.value,null,evidence);
 }
});
test('receipt supports amount written as plain VND digits',()=>{
 const r=validateReceipt({...receipt,amount:{value:150000,evidence:'Phải trả 150000'}},raw+'\nPhải trả 150000');assert.equal(r.amount.value,150000);
});
test('impossible or unsupported dates are not accepted',()=>{
 assert.equal(isoDate('2026-02-31'),false);assert.equal(isoDate('2024-02-29'),true);
 const r=validateReceipt({...receipt,date:{value:'2026-10-24',evidence:'Ngày 25/10/2026'}},raw);assert.equal(r.date.value,null);
});
test('receipt endpoint uses receipt schema and review flag',async()=>{
 await run(receipt,async(url,out)=>{
  const r=await post(url,'/v1/receipt',{receiptText:raw});assert.equal(r.status,200);
  const data=await r.json();assert.equal(data.source,'gemini');assert.equal(data.amount.value,65000);assert.equal(data.needsReview,true);
  assert(out().generationConfig.responseSchema.properties.amount);assert(!out().contents[0].parts[0].text.includes('apiKey'));
 });
});
test('receipt endpoint rejects absent OCR and unauthorised requests',async()=>{
 await run(receipt,async url=>{
  assert.equal((await post(url,'/v1/receipt',{receiptText:''})).status,400);
  assert.equal((await post(url,'/v1/receipt',{receiptText:raw},'wrong')).status,401);
 });
});
test('stats facts are recomputed and client totals cannot override them',()=>{
 const f=summaryFacts({...summary,total:9999999},categories);
 assert.equal(f.total.vnd,100000);assert.equal(f.comparison.percent,100);assert.equal(f.top_category.name,'Ăn uống');assert.equal(f.daily_average.vnd,4000);assert.equal(f.budget.remainingVnd,2900000);
});
test('no previous spending means no fabricated percent',()=>{
 const f=summaryFacts({...summary,previousTotals:[0,0,0,0,0,0],previousCount:0},categories);assert.equal(f.comparison.percent,null);
});
test('invalid stats are rejected before model invocation',()=>{
 for(const change of [{totals:[1]},{totals:[-1,0,0,0,0,0]},{observedDays:0},{count:0},{budget:-1}])assert.throws(()=>summaryFacts({...summary,...change},categories));
});
test('insight wording cannot introduce numeric claims or unknown fact IDs',()=>{
 const facts=summaryFacts(summary,categories);
 assert.throws(()=>validateInsights({headline:'Tăng 999%',focus:['total'],tips:['Xem lại.']},facts));
 assert.throws(()=>validateInsights({headline:'Xem lại',focus:['invented'],tips:['Ghi chép.']},facts));
 assert.throws(()=>validateInsights({headline:'Xem lại',focus:['total','total'],tips:['Ghi chép.']},facts));
});
test('insights endpoint sends only validated aggregate facts',async()=>{
 await run({headline:'Một góc nhìn cho kỳ này',focus:['top_category','comparison'],tips:['Xem lại nhóm ăn uống trước khi điều chỉnh mục tiêu.']},async(url,out)=>{
  const r=await post(url,'/v1/insights',summary);assert.equal(r.status,200);const data=await r.json();assert.equal(data.focus[0],'top_category');
  const sent=JSON.parse(out().contents[0].parts[0].text);assert.equal(sent.facts.total.vnd,100000);assert.equal(sent.receiptText,undefined);assert.equal(sent.merchant,undefined);
 });
});
test('weekly insights cannot refer to a monthly budget',()=>{
 const f=summaryFacts({...summary,period:'week',budget:null,observedDays:7,comparisonDays:7},categories);
 assert.throws(()=>validateInsights({headline:'Xem lại',focus:['budget'],tips:['Cân nhắc mục tiêu.']},f));
});
