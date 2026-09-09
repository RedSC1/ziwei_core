// Run after npm run build --workspace=ziwei-lite in the source repository.
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {writeFileSync} from 'node:fs';
const root=resolve(process.argv[2]);
const z=await import(pathToFileURL(resolve(root,'packages/ziwei/dist/index.js')));
const e=await import(pathToFileURL(resolve(root,'src/index.js')));
const clock=(y,m=1,d=1,h=12)=>({year:y,month:m,day:d,hour:h,minute:0,second:0,offsetMinutes:480});
const clean=v=>JSON.parse(JSON.stringify(v));
const compact=chart=>{const v=chart.toJSON();delete v.options;return v;};
const charts=[];
const dates=[clock(2000),clock(2003,3,14,23),clock(2023,4,6,23),clock(2024,2,9,23),clock(690,1,1),clock(-221,10,1),clock(-720,6,1)];
for(let i=0;i<21;i++) {
 const input=dates[i%dates.length];
 const options={gender:i%2,chartMode:i%3,ratHourMode:['next-day','current-day','current-day-tomorrow-stem'][i%3],eventAccuracy:['fast','mid','accurate'][i%3],leapMonthStrategy:i%3,wuHuDunYearBoundary:i%2,sihuaYearBoundary:(i>>1)%2,bodyMasterYearBoundary:(i>>2)%2};
 if(i%4===1) Object.assign(options,{clockMode:'true-solar',longitudeDeg:116.4074});
 if(i%4===2) Object.assign(options,{clockMode:'mean-solar',longitudeDeg:87.6});
 const chart=z.ZiweiChart.fromZonedTime(new e.ZonedTime(input),options);
 const edits=[{month:12,yearGanIndex:9,yearZhiIndex:7},{day:30,hourZhiIndex:11,updateBureau:true}];
 const m1=chart.modify(edits[0]),m2=m1.modify(edits[1]),shift=m2.shiftLifePalace(-5),reshuffle=shift.modify({day:1});
 charts.push({input,options,expected:compact(chart),edits,modified:[compact(m1),compact(m2),compact(shift),compact(reshuffle)],limits:[chart,m1,m2,shift].map(c=>[z.getEffectiveBirthYear(c),z.getStartDecadeYear(c),z.makeDecadeByIndex(c,z.getEffectiveBirthYear(c),2)])});
}
const casting=[];
for(const [method,values] of Object.entries({index:[0,11,12,359,360,4319,4320,259199],number:['0','0001','123','999999999999999999999999999999999','4294967295']})) {
 for(const value of values) {
 const options={gender:1};const chart=method==='index'?z.ZiweiCastingChart.fromIndex(value,options):z.ZiweiCastingChart.fromNumber(value,options);
 casting.push({method,value,expected:compact(chart),modified:compact(chart.modify({month:8,day:23,updateBureau:true}).shiftLifePalace(3).modify({yearZhiIndex:4}))});
 }
}
const flows=[];
for(let i=0;i<9;i++) {
 const input=clock(-800,6,1,8),options={gender:i%2,leapMonthStrategy:i%3,ratHourMode:['next-day','current-day','current-day-tomorrow-stem'][i%3],flowLimitBoundary:i%2,flowMonthPalaceStrategy:i%2,childhoodStrategy:i%2};
 const c=z.ZiweiChart.fromZonedTime(new e.ZonedTime(input),options),target=clock([2023,-217,690][i%3],i%3===0?4:10,i%3===0?6:1,23),flow=z.resolveZiweiFlow(c,new e.ZonedTime(target));
 const dynamic=z.dynamicChartFromResolvedFlow(c,flow).toJSON();delete dynamic.natal;
 flows.push({input,options,target,expected:flow,dynamic});
}
const timelines=[];
for(const year of [-717,-716,-217,-216,-104,23,237,690,761,2023]) {
 const input=clock(-800,6,1,8),options={gender:0};const c=z.ZiweiChart.fromZonedTime(new e.ZonedTime(input),options),t=c.timeline();
 const months=t.getMonths(year),days=months.length?t.getDays(year,months[0].month,months[0].isLeap,months[0].effectiveMonth,months[0].effectiveYear):[];
 timelines.push({input,options,year,months,days});
}
const rules=[];
for(const patch of [
 {starsJson:JSON.stringify([{key:'extra_star',type:'minor',rule:{type:'constant',value:4}}]),brightnessJson:JSON.stringify({extra_star:[6,6,6,6,6,6,6,6,6,6,6,6]}),sihuaJson:JSON.stringify({jia:{lu:'extra_star'}})},
 {flowJson:JSON.stringify([{key:'extra_flow',rule:{type:'anchor_offset',anchor:'year_branch',offset:2},brightness:[5,5,5,5,5,5,5,5,5,5,5,5]}])},
 {starsJson:JSON.stringify([{key:'ziwei',type:'major',rule:{type:'pipeline',steps:[{type:'constant',value:3},{type:'anchor_offset',anchor:'month',offset:1,direction:-1}]}}])}
 ]) {
 const module=z.ZiweiConfigLoader.compileJson({label:'test',...patch});const opts={gender:0,rules:{ruleset:z.ZiweiConfigLoader.getDefault().with(module)}};const input=clock(2000);const c=z.ZiweiChart.fromZonedTime(new e.ZonedTime(input),opts);
 rules.push({patch,input,expected:compact(c),flow:z.makeFlowLayer(c,0,{stem:0,branch:2})});
}
// BigInt bitsets are derived data; JSON snapshots use stars instead.
for(const r of rules) r.flow={...r.flow,starBitsets:r.flow.starBitsets.map(String)};
writeFileSync('test/fixtures/parity-js.json',JSON.stringify({charts,casting,flows,timelines,rules}));
console.log({charts:charts.length,casting:casting.length,flows:flows.length,timelines:timelines.length,rules:rules.length});
