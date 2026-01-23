#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Claude Code Pattern Auto-Detection Tool                       ║${NC}"
echo -e "${MAGENTA}║  Automatically detect Vietnamese IME pattern in new versions   ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

find_binary() {
    local binary_path=""

    # Check new location first (Claude Code 2.1.17+)
    local user_share="$HOME/.local/share/claude/versions"
    if [[ -d "$user_share" ]]; then
        local latest_version=$(ls -1 "$user_share" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
        if [[ -n "$latest_version" ]] && [[ -f "$user_share/$latest_version" ]]; then
            if file "$user_share/$latest_version" | grep -q "Mach-O"; then
                binary_path="$user_share/$latest_version"
            fi
        fi
    fi

    # Fallback to Homebrew paths
    if [[ -z "$binary_path" ]]; then
        local homebrew_paths=(
            "/opt/homebrew/bin/claude"
            "/usr/local/bin/claude"
            "/opt/homebrew/Caskroom/claude-code/*/claude"
            "/usr/local/Caskroom/claude-code/*/claude"
        )

        for pattern in "${homebrew_paths[@]}"; do
            for path in $pattern; do
                if [[ -f "$path" ]]; then
                    if file "$path" | grep -q "Mach-O"; then
                        binary_path="$path"
                        break 2
                    fi
                fi
            done
        done
    fi

    # Fallback to which claude
    if [[ -z "$binary_path" ]] && command -v claude &> /dev/null; then
        local claude_bin=$(which claude)
        local resolved_path=$(realpath "$claude_bin" 2>/dev/null || readlink -f "$claude_bin" 2>/dev/null || echo "$claude_bin")
        if file "$resolved_path" | grep -q "Mach-O"; then
            binary_path="$resolved_path"
        fi
    fi

    echo "$binary_path"
}

get_version() {
    claude --version 2>/dev/null | head -1 || echo "unknown"
}

echo -e "${YELLOW}→ Đang tìm Claude Code binary...${NC}"
BINARY_PATH=$(find_binary)

if [[ -z "$BINARY_PATH" ]] || [[ ! -f "$BINARY_PATH" ]]; then
    echo -e "${RED}✗ Không tìm thấy Claude Code binary.${NC}"
    exit 1
fi

VERSION=$(get_version)
echo -e "  Đường dẫn: ${BLUE}$BINARY_PATH${NC}"
echo -e "  Phiên bản: ${BLUE}$VERSION${NC}"

# Check if binary is already patched
echo -e "${YELLOW}→ Kiểm tra binary...${NC}"
if strings "$BINARY_PATH" 2>/dev/null | grep -q "PHTV_FIX"; then
    echo -e "${RED}✗ Binary đã được patch rồi!${NC}"
    echo -e "  Vui lòng restore về bản gốc trước hoặc dùng backup file"
    echo -e "  Ví dụ: $BINARY_PATH.backup-*"
    echo ""
    
    # Find backup
    BACKUP=$(ls -t "$BINARY_PATH".backup-* 2>/dev/null | head -1)
    if [[ -n "$BACKUP" ]]; then
        echo -e "${CYAN}Tìm thấy backup: $BACKUP${NC}"
        echo -e "${YELLOW}Sử dụng backup để phân tích? (y/N)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            BINARY_PATH="$BACKUP"
            echo -e "${GREEN}→ Sử dụng backup file${NC}"
        else
            exit 1
        fi
    else
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}→ Đang phân tích binary để tìm pattern...${NC}"

# Use Python to analyze binary and find pattern
python3 - "$BINARY_PATH" "$VERSION" << 'PYTHON_EOF'
import sys
import re

binary_path = sys.argv[1]
version = sys.argv[2]

print(f"Analyzing: {binary_path}")
print(f"Version: {version}")
print()

with open(binary_path, 'rb') as f:
    content = f.read()

print(f"Binary size: {len(content):,} bytes")
print()

# Strategy: Search for the specific pattern structure
# Pattern: if(!X.backspace&&!X.delete&&Y.includes("\x7F"))...return}

print("🔍 Searching for Vietnamese IME handling pattern...")
print()

# Find all occurrences of the characteristic string
search_key = b'.includes("\\x7F")'
occurrences = []
idx = 0
while True:
    idx = content.find(search_key, idx)
    if idx == -1:
        break
    occurrences.append(idx)
    idx += len(search_key)

print(f"Found {len(occurrences)} occurrence(s) of .includes(\"\\x7F\")")

if len(occurrences) == 0:
    print("\n❌ No Vietnamese IME pattern found")
    print("This version might not have the bug, or uses a different implementation.")
    sys.exit(1)

candidates = []

for occ_idx in occurrences:
    # Look backwards to find "if(!"
    search_start = max(0, occ_idx - 100)
    search_chunk = content[search_start:occ_idx]
    
    # Find the last "if(!" before our pattern
    if_pattern = b'if(!'
    if_pos = search_chunk.rfind(if_pattern)
    
    if if_pos == -1:
        continue
    
    # Now find "return}" after the includes
    search_end = min(len(content), occ_idx + 250)
    end_chunk = content[occ_idx:search_end]
    
    return_pattern = b'return}'
    return_pos = end_chunk.find(return_pattern)
    
    if return_pos == -1:
        continue
    
    # Extract the complete pattern
    pattern_start = search_start + if_pos
    pattern_end = occ_idx + return_pos + len(return_pattern)
    full_pattern = content[pattern_start:pattern_end]
    
    # Validate: must contain key elements
    required = [b'backspace', b'delete', b'deleteTokenBefore', b'includes("\\x7F")']
    if all(req in full_pattern for req in required):
        candidates.append({
            'offset': pattern_start,
            'length': len(full_pattern),
            'pattern': full_pattern
        })

print(f"Found {len(candidates)} valid candidate(s)")
print()

if len(candidates) == 0:
    print("❌ No valid pattern found")
    print("The code structure might have changed significantly.")
    sys.exit(1)

# Use first candidate (they should all be identical)
selected = candidates[0]

print("="*80)
print(f"\n✓ Pattern detected successfully!")
print(f"\n  Offset: {selected['offset']}")
print(f"  Length: {selected['length']} bytes")
print(f"  Found at {len(candidates)} location(s)")

if len(candidates) > 1:
    print(f"  All offsets: {[c['offset'] for c in candidates]}")

print(f"\n📄 Full Pattern (raw bytes):")
print(f"  {repr(selected['pattern'])}")

print(f"\n📄 Full Pattern (decoded):")
try:
    decoded = selected['pattern'].decode('utf-8')
    print(f"  {decoded}")
except:
    print("  [Could not decode]")

# Parse variable names
pattern_str = selected['pattern'].decode('utf-8', errors='replace')

print("\n" + "="*80)
print("\n🔍 Analyzing variable names...")

# Extract variables
var_map = {}

# Event variable: if(!X.backspace
m = re.search(r'if\(!(\w+)\.backspace&&!(\w+)\.delete&&(\w+)\.includes', pattern_str)
if m:
    var_map['event'] = m.group(1)
    var_map['input'] = m.group(3)
    print(f"  Event object: {var_map['event']}")
    print(f"  Input string: {var_map['input']}")

# Count variable: let X=(
m = re.search(r'let (\w+)=\([^)]+\.match', pattern_str)
if m:
    var_map['count'] = m.group(1)
    print(f"  Count variable: {var_map['count']}")

# Temp cursor: ,Y=y;
m = re.search(r',(\w+)=y;', pattern_str)
if m:
    var_map['temp'] = m.group(1)
    print(f"  Temp cursor: {var_map['temp']}")

# Iterator: for(let X=
m = re.search(r'for\(let (\w+)=0', pattern_str)
if m:
    var_map['iterator'] = m.group(1)
    print(f"  Iterator: {var_map['iterator']}")

# Offset function: X(Y.offset)
m = re.search(r'(\w+)\([^)]*\.offset\)', pattern_str)
if m:
    var_map['offset_func'] = m.group(1)
    print(f"  Offset function: {var_map['offset_func']}()")

# Ending functions: X(),Y();return
m = re.search(r'(\w+)\(\),(\w+)\(\);return', pattern_str)
if m:
    var_map['func1'] = m.group(1)
    var_map['func2'] = m.group(2)
    print(f"  Ending functions: {var_map['func1']}(), {var_map['func2']}()")

print("\n" + "="*80)
print("\n💡 Generating fixed code...")

# Check if we have all required variables
required_vars = ['event', 'input', 'offset_func', 'func1', 'func2']
if all(v in var_map for v in required_vars):
    e = var_map['event']
    n = var_map['input']
    b = var_map['offset_func']
    f1 = var_map['func1']
    f2 = var_map['func2']
    
    # Generate fixed code
    fixed_template = f'if(!{e}.backspace&&!{e}.delete&&{n}.includes("\\x7F")){{let C={n}.split("\\x7f").length-1,Z=y;while(C--)Z=Z.deleteTokenBefore()??Z.backspace();for(let c of {n}.replace(/\\x7f/g,""))Z=Z.insert(c);R(Z.text);{b}(Z.offset);{f1}(),{f2}();return'
    
    fixed_bytes = fixed_template.encode('utf-8')
    
    print(f"\n✓ Fixed code:")
    print(f"  {fixed_template}")
    print(f"\n  Fixed length: {len(fixed_bytes)} bytes")
    print(f"  Original length: {selected['length']} bytes")
    
    # Calculate padding
    marker = b'/*PHTV_FIX*/'
    padding_needed = selected['length'] - len(fixed_bytes) - 1  # -1 for closing }
    extra_padding = padding_needed - len(marker)
    
    print(f"  Padding needed: {padding_needed} bytes")
    print(f"  Marker length: {len(marker)} bytes")
    print(f"  Extra spaces: {extra_padding}")
    
    if extra_padding >= 0:
        fixed_padded = fixed_bytes + marker + b' ' * extra_padding + b'}'
        
        if len(fixed_padded) == selected['length']:
            print(f"\n  ✅ Length match! {len(fixed_padded)} == {selected['length']}")
            
            print("\n" + "="*80)
            print("\n🎉 SUCCESS! Auto-detection complete.")
            print("\n📋 Update fix-vietnamese-input-binary.sh with these values:")
            print("\n" + "-"*80)
            print(f"original_block = {repr(selected['pattern'])}")
            print()
            print(f"fixed_code = {repr(fixed_bytes)}")
            print("-"*80)
            
            # Generate version info
            print(f"\n📝 Version Info:")
            print(f"   Claude Code: {version}")
            print(f"   Pattern length: {selected['length']} bytes")
            print(f"   Variable mapping:")
            for k, v in var_map.items():
                print(f"     {k}: {v}")
                
        else:
            print(f"\n  ❌ Length mismatch: {len(fixed_padded)} != {selected['length']}")
    else:
        print(f"\n  ❌ Marker too long! Need {-extra_padding} bytes less")
else:
    missing = [v for v in required_vars if v not in var_map]
    print(f"\n⚠️  Cannot auto-generate fix. Missing variables: {missing}")
    print("Manual analysis required.")

print("\n" + "="*80)

PYTHON_EOF

echo ""
echo -e "${GREEN}✓ Analysis complete!${NC}"
