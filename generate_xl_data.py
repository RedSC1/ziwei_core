"""Parse xl0_data.txt and xl1_data.txt, generate xl_data.dart."""
import re
import os

def parse_numbers_from_block(text):
    """Extract all numbers from a block of text between [ and ]."""
    # Remove comments
    text = re.sub(r'//.*', '', text)
    # Find all numbers (integers, decimals, negative)
    nums = re.findall(r'-?\d+\.?\d*(?:[eE][+-]?\d+)?', text)
    return nums

def parse_xl0(filepath):
    """Parse xl0_data.txt into 8 arrays."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by the XL0[n] comments to find each block
    # Pattern: // XL0[n] - Name, length=...
    pattern = r'//\s*XL0\[\d+\]\s*-\s*\w+'
    parts = re.split(pattern, content)
    
    # parts[0] is before first match (empty or whitespace)
    # parts[1..8] are the 8 planet blocks
    
    arrays = []
    for i in range(1, len(parts)):
        block = parts[i]
        # Find everything between [ and ] (the block may contain the length info before [)
        # We need to find the bracket-enclosed content
        bracket_start = block.find('[')
        bracket_end = block.rfind(']')
        if bracket_start >= 0 and bracket_end >= 0:
            inner = block[bracket_start+1:bracket_end]
            nums = parse_numbers_from_block(inner)
            arrays.append(nums)
    
    return arrays

def parse_xl1(filepath):
    """Parse xl1_data.txt into structured arrays."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Labels we expect in order
    labels = ['ML0', 'ML1', 'ML2', 'ML3', 'MB0', 'MB1', 'MB2', 'MR0', 'MR1', 'MR2']
    
    # Split by these labels
    pattern = r'//\s*(?:XL1\[\d+\]\s*-\s*\w+\s*\n\s*//\s*)?(?:ML\d|MB\d|MR\d)'
    
    # Better approach: find each labeled section
    sections = {}
    for label in labels:
        # Find the label comment and then the [...] block after it
        label_pattern = r'//\s*' + label + r'[^\[]*\['
        match = re.search(label_pattern, content)
        if match:
            start = match.end()  # right after the [
            # Find matching ]
            depth = 1
            pos = start
            while pos < len(content) and depth > 0:
                if content[pos] == '[':
                    depth += 1
                elif content[pos] == ']':
                    depth -= 1
                pos += 1
            inner = content[start:pos-1]
            nums = parse_numbers_from_block(inner)
            sections[label] = nums
    
    return sections

def format_numbers(nums, indent=2):
    """Format a list of number strings into Dart array content."""
    lines = []
    line = ' ' * indent
    count = 0
    for i, n in enumerate(nums):
        # Determine if it's an integer or float
        entry = n
        if '.' not in n and 'e' not in n.lower():
            # Integer - but in Dart const List<double>, we need to keep as-is
            # Dart will auto-convert int literals in List<double>
            pass
        
        if i < len(nums) - 1:
            entry += ', '
        else:
            entry += ','
        
        if len(line) + len(entry) > 120:
            lines.append(line.rstrip())
            line = ' ' * indent + entry
        else:
            line += entry
    
    if line.strip():
        lines.append(line.rstrip())
    
    return '\n'.join(lines)

def main():
    base = r'E:\ziwei_core_v2\ziwei_core'
    xl0_path = os.path.join(base, 'xl0_data.txt')
    xl1_path = os.path.join(base, 'xl1_data.txt')
    out_path = os.path.join(base, 'lib', 'src', 'sxwnl', 'xl_data.dart')
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    
    print("Parsing xl0_data.txt...")
    xl0_arrays = parse_xl0(xl0_path)
    print(f"  Found {len(xl0_arrays)} arrays")
    for i, a in enumerate(xl0_arrays):
        print(f"  XL0[{i}]: {len(a)} numbers")
    
    print("Parsing xl1_data.txt...")
    xl1_sections = parse_xl1(xl1_path)
    for label in ['ML0', 'ML1', 'ML2', 'ML3', 'MB0', 'MB1', 'MB2', 'MR0', 'MR1', 'MR2']:
        if label in xl1_sections:
            print(f"  {label}: {len(xl1_sections[label])} numbers")
        else:
            print(f"  {label}: MISSING!")
    
    planet_names = ['Earth', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune']
    
    print("Generating Dart file...")
    
    with open(out_path, 'w', encoding='utf-8') as f:
        # Header
        f.write("""/// VSOP87 行星星历和月球星历数据表。
///
/// 移植自寿星万年历 (sxwnl) eph0.js。
/// 原作者：许剑伟
///
/// XL0: 8行星星历（地球、水星、金星、火星、木星、土星、天王星、海王星）
/// XL1: 月球星历（黄经、黄纬、距离）
library;

// ==================== XL0: 行星星历 ====================

/// 行星修正表（7颗行星 × 3个坐标）
const List<double> xl0Xzb = [
  -0.08631, 0.00039, -0.00008,  // Mercury
  -0.07447, 0.00006, 0.00017,   // Venus
  -0.07135, -0.00026, -0.00176, // Mars
  -0.20239, 0.00273, -0.00347,  // Jupiter
  -0.25486, 0.00276, 0.42926,   // Saturn
  0.24588, 0.00345, -14.46266,  // Uranus
  -0.95116, 0.02481, 58.30651,  // Neptune
];

/// XL0 行星星历数据（8个子数组）
/// 每个子数组结构：[倍率, 19个位置索引, 系数三元组(A,B,C)...]
const List<List<double>> xl0 = [
""")
        
        # Write XL0 arrays
        for i, arr in enumerate(xl0_arrays):
            f.write(f"  // XL0[{i}] - {planet_names[i]}\n")
            f.write("  [\n")
            f.write(format_numbers(arr, indent=4))
            f.write("\n  ],\n")
            if i < len(xl0_arrays) - 1:
                f.write("\n")
        
        f.write("""];

// ==================== XL1: 月球星历 ====================

/// XL1 月球星历数据
/// 结构：xl1[坐标][t的幂次] = [6元组(A,相位,频率,t2系数,t3系数,t4系数)...]
/// 坐标：0=黄经, 1=黄纬, 2=距离
const List<List<List<double>>> xl1 = [
""")
        
        # XL1[0] - Longitude
        f.write("  // XL1[0] - Longitude\n")
        f.write("  [\n")
        for label in ['ML0', 'ML1', 'ML2', 'ML3']:
            f.write(f"    // {label}\n")
            f.write("    [\n")
            f.write(format_numbers(xl1_sections[label], indent=6))
            f.write("\n    ],\n")
        f.write("  ],\n\n")
        
        # XL1[1] - Latitude
        f.write("  // XL1[1] - Latitude\n")
        f.write("  [\n")
        for label in ['MB0', 'MB1', 'MB2']:
            f.write(f"    // {label}\n")
            f.write("    [\n")
            f.write(format_numbers(xl1_sections[label], indent=6))
            f.write("\n    ],\n")
        f.write("  ],\n\n")
        
        # XL1[2] - Distance
        f.write("  // XL1[2] - Distance\n")
        f.write("  [\n")
        for label in ['MR0', 'MR1', 'MR2']:
            f.write(f"    // {label}\n")
            f.write("    [\n")
            f.write(format_numbers(xl1_sections[label], indent=6))
            f.write("\n    ],\n")
        f.write("  ],\n")
        
        f.write("];\n")
    
    file_size = os.path.getsize(out_path)
    print(f"Done! Generated {out_path}")
    print(f"File size: {file_size} bytes ({file_size/1024:.1f} KB)")

if __name__ == '__main__':
    main()
