import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {writeFileSync} from 'node:fs';
const root=resolve(process.argv[2]);
const z=await import(pathToFileURL(resolve(root,'packages/ziwei/dist/index.js')));
const e=await import(pathToFileURL(resolve(root,'src/index.js')));
const r=await import(pathToFileURL(resolve(root,'packages/ziwei/dist/generated/default-rules.js')));
const clock=(year,month=1,day=1,hour=12)=>new e.ZonedTime({year,month,day,hour,minute:0,second:0,offsetMinutes:480});
const variants=[];
for(const [kind,rows] of Object.entries({placement:r.GENERATED_PLACEMENT_VARIANTS,brightness:r.GENERATED_BRIGHTNESS_VARIANTS,sihua:r.GENERATED_SIHUA_VARIANTS})) {
 for(const row of rows) for(const option of Object.keys(row.options)) {
 if(option==='option1') continue;
 const key=row.starKey??row.stemKey;
 const rule={[kind]:{[key]:option}};
 if(['changsheng','muyu','guandai','linguan','diwang','shuai','bing','si','mu','jue','tai','yang'].includes(key)) Object.assign(rule,{longevity:option});
 const c=z.ZiweiChart.fromZonedTime(clock(2003,3,14,0),{gender:1,rules:rule});
 variants.push({rule,positions:c.starPositions,masks:c.transformationMasks,masters:[c.lifeMaster,c.bodyMaster],brightness:c.starCatalog.map(s=>c.getStarPosition(s.id)?.brightness??null)});
 }
}
const reverse=[];
for(const clockMode of ['civil','true-solar']) for(const ratHourMode of ['next-day','current-day-tomorrow-stem']) {
 const options={gender:0,clockMode,longitudeDeg:116.4074,ratHourMode};const birth=clock(2000),c=z.ZiweiChart.fromZonedTime(birth,options),branch=k=>c.starPositions[z.findStarId(k)];
 for(const direct of [false,true]) {
 const query={lucunBranch:branch('lucun'),...(direct?{hongluanBranch:branch('hongluan'),zuofuBranch:branch('zuofu'),wenchangBranch:branch('wenchang'),santaiBranch:branch('santai')}:{})};
 const start=clock(1999,12,31,0),end=clock(2000,1,2,23);
 const candidates=z.reverseLookupZiweiTier1({start,end,options,query});
 reverse.push({options,query,start:start.toJSON(),end:end.toJSON(),expected:candidates.map(v=>({jdUT1:v.jdUT1,hourBranch:v.hourBranch,ratHourSegment:v.ratHourSegment,starPositions:v.chart.starPositions}))});
 }
}
writeFileSync('test/fixtures/extra-js.json',JSON.stringify({variants,reverse}));
console.log({variants:variants.length,reverse:reverse.length});
