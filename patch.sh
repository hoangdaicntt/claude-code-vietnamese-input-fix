#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PATCH_MARKER="PHTV_FIX"

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Claude Code Vietnamese IME Fix - AUTO PATCH                   ║${NC}"
echo -e "${MAGENTA}║  Auto-detect pattern and apply patch automatically             ║${NC}"
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

is_patched() {
    local binary_path="$1"
    strings "$binary_path" 2>/dev/null | grep -q "$PATCH_MARKER"
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
echo ""

# Check if already patched
if is_patched "$BINARY_PATH"; then
    echo -e "${GREEN}✓ Binary đã được patch rồi!${NC}"
    echo -e "  Không cần patch lại."
    exit 0
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  BƯỚC 1: AUTO-DETECT PATTERN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Auto-detect pattern using Python
echo -e "${YELLOW}→ Đang phân tích binary để tìm pattern...${NC}"

PATTERN_RESULT=$(python3 - "$BINARY_PATH" << 'PYTHON_EOF'
import sys
import re

binary_path = sys.argv[1]

with open(binary_path, 'rb') as f:
    content = f.read()

# Find pattern
search_key = b'.includes("\\x7F")'
occurrences = []
idx = 0
while True:
    idx = content.find(search_key, idx)
    if idx == -1:
        break
    occurrences.append(idx)
    idx += len(search_key)

if len(occurrences) == 0:
    print("ERROR:NO_PATTERN")
    sys.exit(1)

candidates = []
for occ_idx in occurrences:
    search_start = max(0, occ_idx - 100)
    search_chunk = content[search_start:occ_idx]
    
    if_pattern = b'if(!'
    if_pos = search_chunk.rfind(if_pattern)
    if if_pos == -1:
        continue
    
    search_end = min(len(content), occ_idx + 250)
    end_chunk = content[occ_idx:search_end]
    
    return_pattern = b'return}'
    return_pos = end_chunk.find(return_pattern)
    if return_pos == -1:
        continue
    
    pattern_start = search_start + if_pos
    pattern_end = occ_idx + return_pos + len(return_pattern)
    full_pattern = content[pattern_start:pattern_end]
    
    required = [b'backspace', b'delete', b'deleteTokenBefore', b'includes("\\x7F")']
    if all(req in full_pattern for req in required):
        candidates.append({
            'offset': pattern_start,
            'length': len(full_pattern),
            'pattern': full_pattern
        })

if len(candidates) == 0:
    print("ERROR:NO_VALID_PATTERN")
    sys.exit(1)

selected = candidates[0]
pattern_str = selected['pattern'].decode('utf-8', errors='replace')

# Parse variables
var_map = {}
m = re.search(r'if\(!(\w+)\.backspace&&!(\w+)\.delete&&(\w+)\.includes', pattern_str)
if m:
    var_map['event'] = m.group(1)
    var_map['input'] = m.group(3)

m = re.search(r'(\w+)\([^)]*\.offset\)', pattern_str)
if m:
    var_map['offset_func'] = m.group(1)

m = re.search(r'(\w+)\(\),(\w+)\(\);return', pattern_str)
if m:
    var_map['func1'] = m.group(1)
    var_map['func2'] = m.group(2)

required_vars = ['event', 'input', 'offset_func', 'func1', 'func2']
if not all(v in var_map for v in required_vars):
    print("ERROR:CANNOT_PARSE_VARS")
    sys.exit(1)

# Generate fixed code
e = var_map['event']
n = var_map['input']
b = var_map['offset_func']
f1 = var_map['func1']
f2 = var_map['func2']

fixed_template = f'if(!{e}.backspace&&!{e}.delete&&{n}.includes("\\x7F")){{let C={n}.split("\\x7f").length-1,Z=y;while(C--)Z=Z.deleteTokenBefore()??Z.backspace();for(let c of {n}.replace(/\\x7f/g,""))Z=Z.insert(c);R(Z.text);{b}(Z.offset);{f1}(),{f2}();return'
fixed_bytes = fixed_template.encode('utf-8')

# Output in format: SUCCESS|original_bytes|fixed_bytes|length|count
import base64
original_b64 = base64.b64encode(selected['pattern']).decode('ascii')
fixed_b64 = base64.b64encode(fixed_bytes).decode('ascii')

print(f"SUCCESS|{original_b64}|{fixed_b64}|{selected['length']}|{len(candidates)}")

PYTHON_EOF
)

# Parse result
if [[ "$PATTERN_RESULT" == ERROR:* ]]; then
    ERROR_TYPE="${PATTERN_RESULT#ERROR:}"
    echo -e "${RED}✗ Auto-detect thất bại: $ERROR_TYPE${NC}"
    echo ""
    echo -e "Vui lòng:"
    echo -e "  1. Kiểm tra phiên bản Claude Code"
    echo -e "  2. Thử chạy: ${CYAN}./auto-detect-pattern.sh${NC} để xem chi tiết"
    echo -e "  3. Hoặc update pattern thủ công trong fix-vietnamese-input-binary.sh"
    exit 1
fi

# Extract values
IFS='|' read -r STATUS ORIGINAL_B64 FIXED_B64 PATTERN_LENGTH PATTERN_COUNT <<< "$PATTERN_RESULT"

echo -e "${GREEN}✓ Đã phát hiện pattern!${NC}"
echo -e "  Độ dài: ${BLUE}$PATTERN_LENGTH bytes${NC}"
echo -e "  Xuất hiện: ${BLUE}$PATTERN_COUNT vị trí${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  BƯỚC 2: APPLY PATCH${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}⚠️  Bạn có muốn áp dụng patch không?${NC}"
echo -e "   ${CYAN}Phiên bản:${NC} $VERSION"
echo -e "   ${CYAN}Binary:${NC} $BINARY_PATH"
echo ""
echo -e "   Nhấn Enter để tiếp tục, Ctrl+C để hủy..."
read -r

# Create backup
BACKUP_PATH="${BINARY_PATH}.backup-$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}→ Đang tạo backup...${NC}"
cp "$BINARY_PATH" "$BACKUP_PATH"
echo -e "  Backup: ${BLUE}$BACKUP_PATH${NC}"

# Apply patch
echo -e "${YELLOW}→ Đang áp dụng patch...${NC}"

PATCH_RESULT=$(python3 - "$BINARY_PATH" "$PATCH_MARKER" "$ORIGINAL_B64" "$FIXED_B64" "$PATTERN_LENGTH" << 'PYTHON_EOF'
import sys
import base64

binary_path = sys.argv[1]
patch_marker = sys.argv[2]
original_b64 = sys.argv[3]
fixed_b64 = sys.argv[4]
pattern_length = int(sys.argv[5])

# Decode patterns
original_block = base64.b64decode(original_b64)
fixed_code = base64.b64decode(fixed_b64)

with open(binary_path, 'rb') as f:
    content = bytearray(f.read())

original_size = len(content)

# Check if already patched
if patch_marker.encode() in content:
    print("ALREADY_PATCHED")
    sys.exit(0)

# Calculate padding
padding_needed = len(original_block) - len(fixed_code) - 1
marker_comment = f'/*{patch_marker}*/'.encode()
extra_padding = padding_needed - len(marker_comment)

if extra_padding < 0:
    print("ERROR:MARKER_TOO_LONG")
    sys.exit(1)

fixed_padded = fixed_code + marker_comment + b' ' * extra_padding + b'}'

if len(original_block) != len(fixed_padded):
    print(f"ERROR:LENGTH_MISMATCH:{len(original_block)}!={len(fixed_padded)}")
    sys.exit(1)

# Find and replace
idx = content.find(original_block)
count = 0
while idx != -1:
    count += 1
    content[idx:idx+len(original_block)] = fixed_padded
    idx = content.find(original_block, idx + 1)

if count == 0:
    print("ERROR:PATTERN_NOT_FOUND")
    sys.exit(1)

# Write patched binary
with open(binary_path, 'wb') as f:
    f.write(content)

new_size = len(content)
if original_size != new_size:
    print("ERROR:SIZE_CHANGED")
    sys.exit(1)

print(f"SUCCESS:{count}")

PYTHON_EOF
)

# Check patch result
if [[ "$PATCH_RESULT" == ERROR:* ]]; then
    echo -e "${RED}✗ Patch thất bại: ${PATCH_RESULT#ERROR:}${NC}"
    echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
    cp "$BACKUP_PATH" "$BINARY_PATH"
    exit 1
fi

PATCH_COUNT="${PATCH_RESULT#SUCCESS:}"
echo -e "${GREEN}✓ Patch áp dụng thành công tại $PATCH_COUNT vị trí${NC}"

# Re-sign binary
echo -e "${YELLOW}→ Đang re-sign binary...${NC}"
codesign --remove-signature "$BINARY_PATH" 2>/dev/null || true
if ! codesign -s - -f "$BINARY_PATH" 2>/dev/null; then
    echo -e "${RED}✗ Re-sign thất bại!${NC}"
    echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
    cp "$BACKUP_PATH" "$BINARY_PATH"
    exit 1
fi

# Verify binary
echo -e "${YELLOW}→ Đang kiểm tra binary...${NC}"
if ! "$BINARY_PATH" --version &> /dev/null; then
    echo -e "${RED}✗ Binary không chạy được sau khi patch!${NC}"
    echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
    cp "$BACKUP_PATH" "$BINARY_PATH"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ PATCH THÀNH CÔNG!                                          ║${NC}"
echo -e "${GREEN}║  Vietnamese IME fix đã được áp dụng tự động.                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "📋 Thông tin:"
echo -e "   ${CYAN}Phiên bản:${NC} $VERSION"
echo -e "   ${CYAN}Pattern:${NC} $PATTERN_LENGTH bytes tại $PATCH_COUNT vị trí"
echo -e "   ${CYAN}Backup:${NC} $BACKUP_PATH"
echo ""
echo -e "${YELLOW}⚠️  Vui lòng khởi động lại Claude Code để áp dụng thay đổi.${NC}"
echo ""
echo -e "${BLUE}Nếu gặp vấn đề, khôi phục bằng:${NC}"
echo -e "  ./fix-vietnamese-input-binary.sh restore"
echo ""
