// Extract XL0, XL1, XL0_xzb data from eph0.js - FIXED version
const fs = require('fs');
const src = fs.readFileSync('eph0.js', 'utf8');

// ---- Extract XL0 ----
// XL0 = new Array( new Array(...), new Array(...), ... new Array(...) );
// 8 planet sub-arrays: Earth, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune

const xl0Start = src.indexOf('var XL0 = new Array(');
const xl0PlutoStart = src.indexOf('var XL0Pluto=');
const xl0End = src.lastIndexOf(');', xl0PlutoStart);
const xl0Block = src.substring(xl0Start, xl0End + 2);

function findInnerNewArrays(block) {
  // Skip the first "new Array(" which is the outer declaration
  const outerParen = block.indexOf('(');
  let pos = outerParen + 1;
  const results = [];
  
  while (pos < block.length) {
    const nextNew = block.indexOf('new Array(', pos);
    if (nextNew === -1) break;
    
    // Find opening paren
    const innerStart = block.indexOf('(', nextNew);
    
    // Find matching close paren
    let depth = 1;
    let i = innerStart + 1;
    for (; i < block.length; i++) {
      if (block[i] === '(') depth++;
      if (block[i] === ')') {
        depth--;
        if (depth === 0) break;
      }
    }
    
    const content = block.substring(innerStart + 1, i);
    
    // Clean: remove /* */ and // comments
    let clean = content.replace(/\/\*[^*]*\*\//g, '');
    clean = clean.replace(/\/\/[^\r\n]*/g, '');
    
    // Extract numbers
    const nums = clean.match(/-?\d+\.?\d*(?:[eE][+-]?\d+)?/g);
    if (nums && nums.length > 3) {
      results.push(nums.map(Number));
    }
    
    pos = i + 1;
  }
  
  return results;
}

const xl0Arrays = findInnerNewArrays(xl0Block);
console.log(`XL0: Found ${xl0Arrays.length} sub-arrays`);
const planetNames = ['Earth', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune'];
for (let i = 0; i < xl0Arrays.length; i++) {
  console.log(`  XL0[${i}] (${planetNames[i]}): ${xl0Arrays[i].length} numbers, multiplier=${xl0Arrays[i][0]}`);
}

// Write XL0 data  
let xl0Out = '';
for (let i = 0; i < xl0Arrays.length; i++) {
  xl0Out += `// XL0[${i}] - ${planetNames[i]}, length=${xl0Arrays[i].length}\n`;
  // Write numbers in rows of 20 for readability
  const nums = xl0Arrays[i];
  xl0Out += '[\n';
  for (let j = 0; j < nums.length; j += 20) {
    const slice = nums.slice(j, Math.min(j + 20, nums.length));
    xl0Out += '  ' + slice.join(', ') + ',\n';
  }
  xl0Out += '],\n\n';
}
fs.writeFileSync('xl0_data.txt', xl0Out);
console.log('Wrote xl0_data.txt (' + Math.round(xl0Out.length/1024) + ' KB)');

// ---- Extract XL1 ----
const xl1Start = src.indexOf('var XL1=new Array(');
const xl1EndMarker = src.indexOf('var XL0_xzb');
const xl1End = src.lastIndexOf(');', xl1EndMarker);
const xl1Block = src.substring(xl1Start, xl1End + 2);

// XL1 has structure: XL1 = [ [ML0,ML1,ML2,ML3], [MB0,MB1,MB2], [MR0,MR1,MR2] ]
// 3 groups, each wrapped in "new Array(" containing nested "new Array("

function extractXL1Groups(block) {
  // Skip outer "var XL1=new Array("
  const outerParen = block.indexOf('(');
  let pos = outerParen + 1;
  const groups = [];
  
  while (pos < block.length) {
    // Find next "new Array(" at the group level
    // Groups start with "new Array(" that contains nested "new Array("
    const nextNA = block.indexOf('new Array(', pos);
    if (nextNA === -1) break;
    
    // Find matching close
    const startP = block.indexOf('(', nextNA);
    let depth = 1, i = startP + 1;
    for (; i < block.length; i++) {
      if (block[i] === '(') depth++;
      if (block[i] === ')') { depth--; if (depth === 0) break; }
    }
    
    const groupContent = block.substring(startP + 1, i);
    
    // Check if this group contains nested "new Array(" - if yes, it's a group; if no, it's a leaf
    if (groupContent.indexOf('new Array(') !== -1) {
      // This is a group - extract inner arrays
      const innerArrays = [];
      let innerPos = 0;
      while (true) {
        const innerNA = groupContent.indexOf('new Array(', innerPos);
        if (innerNA === -1) break;
        
        const innerStartP = groupContent.indexOf('(', innerNA);
        let d = 1, k = innerStartP + 1;
        for (; k < groupContent.length; k++) {
          if (groupContent[k] === '(') d++;
          if (groupContent[k] === ')') { d--; if (d === 0) break; }
        }
        
        let leafContent = groupContent.substring(innerStartP + 1, k);
        leafContent = leafContent.replace(/\/\*[^*]*\*\//g, '');
        leafContent = leafContent.replace(/\/\/[^\r\n]*/g, '');
        const nums = leafContent.match(/-?\d+\.?\d*(?:[eE][+-]?\d+)?/g);
        if (nums && nums.length > 0) {
          innerArrays.push(nums.map(Number));
        }
        innerPos = k + 1;
      }
      if (innerArrays.length > 0) groups.push(innerArrays);
    }
    
    pos = i + 1;
  }
  return groups;
}

const xl1Groups = extractXL1Groups(xl1Block);
console.log(`\nXL1: Found ${xl1Groups.length} top-level groups`);
const xl1Names = [['ML0','ML1','ML2','ML3'], ['MB0','MB1','MB2'], ['MR0','MR1','MR2']];
const xl1GroupNames = ['Longitude', 'Latitude', 'Distance'];

let xl1Out = '';
for (let i = 0; i < xl1Groups.length; i++) {
  console.log(`  XL1[${i}] (${xl1GroupNames[i]}): ${xl1Groups[i].length} sub-arrays`);
  xl1Out += `// XL1[${i}] - ${xl1GroupNames[i]}\n`;
  for (let j = 0; j < xl1Groups[i].length; j++) {
    const name = xl1Names[i] ? xl1Names[i][j] : `sub${j}`;
    const nums = xl1Groups[i][j];
    console.log(`    ${name}: ${nums.length} numbers (${nums.length/6} terms)`);
    xl1Out += `// ${name}, length=${nums.length}, terms=${nums.length/6}\n`;
    xl1Out += '[\n';
    for (let k = 0; k < nums.length; k += 6) {
      const slice = nums.slice(k, Math.min(k + 6, nums.length));
      xl1Out += '  ' + slice.join(', ') + ',\n';
    }
    xl1Out += '],\n\n';
  }
}
fs.writeFileSync('xl1_data.txt', xl1Out);
console.log('Wrote xl1_data.txt (' + Math.round(xl1Out.length/1024) + ' KB)');

// ---- Extract XL0_xzb ----
const xzbStart2 = src.indexOf('var XL0_xzb = new Array(');
const xzbParen = src.indexOf('(', xzbStart2);
let xzbDepth = 1, xzbI = xzbParen + 1;
for (; xzbI < src.length; xzbI++) {
  if (src[xzbI] === '(') xzbDepth++;
  if (src[xzbI] === ')') { xzbDepth--; if (xzbDepth === 0) break; }
}
let xzbContent2 = src.substring(xzbParen + 1, xzbI);
xzbContent2 = xzbContent2.replace(/\/\/[^\r\n]*/g, '');
const xzbNums2 = xzbContent2.match(/-?\d+\.?\d*(?:[eE][+-]?\d+)?/g);
const xzbData2 = xzbNums2.map(Number);
console.log(`\nXL0_xzb: ${xzbData2.length} numbers`);
console.log(JSON.stringify(xzbData2));
fs.writeFileSync('xl0_xzb_data.txt', '// XL0_xzb, length=' + xzbData2.length + '\n' + JSON.stringify(xzbData2) + '\n');

// ---- Extract functions ----
let funcOut = '';

// gxc_sunLon (including the e variable)
const sunLonIdx = src.indexOf('function gxc_sunLon(t)');
const sunLonEndIdx = src.indexOf('}', sunLonIdx) + 1;
funcOut += '// === gxc_sunLon ===\n';
funcOut += src.substring(sunLonIdx, sunLonEndIdx).replace(/\r/g, '') + '\n\n';

// gxc_moonLon
const moonLonIdx = src.indexOf('function gxc_moonLon(t)');
const moonLonEndIdx = src.indexOf('}', moonLonIdx) + 1;
funcOut += '// === gxc_moonLon ===\n';
funcOut += src.substring(moonLonIdx, moonLonEndIdx).replace(/\r/g, '') + '\n\n';

// gxc_moonLat
const moonLatIdx = src.indexOf('function gxc_moonLat(t)');
const moonLatEndIdx = src.indexOf('}', moonLatIdx) + 1;
funcOut += '// === gxc_moonLat ===\n';
funcOut += src.substring(moonLatIdx, moonLatEndIdx).replace(/\r/g, '') + '\n\n';

// E_v
const evIdx = src.indexOf('E_v:function(t)');
const evEndIdx = src.indexOf('},', evIdx) + 2;
funcOut += '// === E_v ===\n';
funcOut += src.substring(evIdx, evEndIdx).replace(/\r/g, '') + '\n\n';

// M_v  
const mvIdx = src.indexOf('M_v:function(t)');
const mvEndIdx = src.indexOf('},', mvIdx) + 2;
funcOut += '// === M_v ===\n';
funcOut += src.substring(mvIdx, mvEndIdx).replace(/\r/g, '') + '\n\n';

// XL1_calc for reference
const xl1CalcIdx = src.indexOf('function XL1_calc(zn,t,n)');
const xl1CalcEndIdx = src.indexOf('};', xl1CalcIdx) + 2;
funcOut += '// === XL1_calc ===\n';
funcOut += src.substring(xl1CalcIdx, xl1CalcEndIdx).replace(/\r/g, '') + '\n\n';

// XL0_calc for reference
const xl0CalcIdx = src.indexOf('function XL0_calc(xt,zn,t,n)');
const xl0CalcEndIdx = src.indexOf('\n\n', xl0CalcIdx + 100);
funcOut += '// === XL0_calc ===\n';
funcOut += src.substring(xl0CalcIdx, xl0CalcEndIdx).replace(/\r/g, '') + '\n\n';

fs.writeFileSync('functions_data.txt', funcOut);
console.log('\nWrote functions_data.txt');

// ---- Verification summary ----
console.log('\n=== VERIFICATION SUMMARY ===');
let totalXL0 = 0;
for (let i = 0; i < xl0Arrays.length; i++) {
  totalXL0 += xl0Arrays[i].length;
}
console.log(`XL0 total numbers across all planets: ${totalXL0}`);

let totalXL1 = 0;
for (let i = 0; i < xl1Groups.length; i++) {
  for (let j = 0; j < xl1Groups[i].length; j++) {
    totalXL1 += xl1Groups[i][j].length;
  }
}
console.log(`XL1 total numbers across all groups: ${totalXL1}`);

console.log('\nDone!');
