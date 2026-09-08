// Usage after building JS: node tool/import_js_rules.mjs /path/to/taiyin-lite
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { writeFileSync } from 'node:fs';
const root = resolve(process.argv[2]);
const rules = await import(pathToFileURL(resolve(root,'packages/ziwei/dist/generated/default-rules.js')));
const api = await import(pathToFileURL(resolve(root,'packages/ziwei/dist/index.js')));
const literal = value => typeof value === 'string' ? JSON.stringify(value).replaceAll('$','\\$') : Array.isArray(value) ? `[${value.map(literal).join(',')}]` : value && typeof value === 'object' ? `{${Object.entries(value).map(([k,v])=>`${literal(k)}:${literal(v)}`).join(',')}}` : String(value);
writeFileSync('lib/src/generated/rules.dart','// Generated from ziwei-lite; see tool/import_js_rules.mjs.\nconst bundledRules = '+literal(rules)+';\n');
const cases=[];
for(let i=0;i<360;i++) {
 const input={yearGanIndex:i%10,yearZhiIndex:i%12,month:1+i%12,day:1+i%30,hourZhiIndex:(i*7)%12};
 const options={gender:i%2,chartMode:i%3};
 cases.push({input,options,expected:api.arrangeZiweiStars(input,options)});
}
for (let gan=0;gan<10;gan++) for(let zhi=0;zhi<12;zhi++) {
 const input={yearGanIndex:gan,yearZhiIndex:zhi,month:12,day:30,hourZhiIndex:11};
 const options={gender:1};
 cases.push({input,options,expected:api.arrangeZiweiStars(input,options)});
}
writeFileSync('test/fixtures/placement-js.json',JSON.stringify(cases));
const eph=await import(pathToFileURL(resolve(root,'src/index.js')));
const births=[];
const dates=[[2000,1,1,12],[2023,3,22,23],[2023,4,6,23],[2024,2,9,23],
 [2024,2,10,0],[2024,2,4,16],[1900,1,1,12],[689,12,20,12],[-221,10,1,12]];
for(const [year,month,day,hour] of dates) for(const accuracy of ['fast','mid','accurate']) {
 const clock={year,month,day,hour,minute:0,second:0,offsetMinutes:480};
 const options={gender:0,eventAccuracy:accuracy};
 const result=api.resolveZiweiBirth(new eph.ZonedTime(clock),options);
 births.push({clock,options,expected:{solar:result.anchors.solarTerm,lunar:result.anchors.lunar,
   bureau:result.anchors.bureau,ziwei:result.anchors.ziwei,tianfu:result.anchors.tianfu,
   palaces:result.anchors.palacePositions,body:result.bodyPalace,
   effectiveYear:result.facts.effectiveLunarYear,effectiveMonth:result.facts.effectiveLunarMonth,
   day:result.facts.lunarDate.day,solarDay:result.facts.solarDayFromPreviousJie}});
}
writeFileSync('test/fixtures/calendar-js.json',JSON.stringify(births));
