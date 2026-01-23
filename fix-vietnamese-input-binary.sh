#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

PATCH_MARKER="PHTV_FIX"

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  Claude Code Vietnamese IME Fix - BINARY PATCH                 ║${NC}"
echo -e "${MAGENTA}║  Supports: Claude Code v2.1.17                                 ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

find_binary() {
    local binary_path=""

    # Check new location first (Claude Code 2.1.17+)
    local user_share="$HOME/.local/share/claude/versions"
    if [[ -d "$user_share" ]]; then
        # Find the latest version
        local latest_version=$(ls -1 "$user_share" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
        if [[ -n "$latest_version" ]] && [[ -f "$user_share/$latest_version" ]]; then
            if file "$user_share/$latest_version" | grep -q "Mach-O"; then
                binary_path="$user_share/$latest_version"
            fi
        fi
    fi

    # Fallback to Homebrew paths if not found
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

    # Fallback to `which claude` if still not found
    if [[ -z "$binary_path" ]] && command -v claude &> /dev/null; then
        local claude_bin=$(which claude)
        local resolved_path=$(realpath "$claude_bin" 2>/dev/null || readlink -f "$claude_bin" 2>/dev/null || echo "$claude_bin")

        if file "$resolved_path" | grep -q "Mach-O"; then
            binary_path="$resolved_path"
        fi
    fi

    echo "$binary_path"
}

is_patched() {
    local binary_path="$1"
    strings "$binary_path" 2>/dev/null | grep -q "$PATCH_MARKER"
}

get_version() {
    claude --version 2>/dev/null | head -1 || echo "unknown"
}

apply_patch() {
    local binary_path="$1"
    local backup_path="${binary_path}.backup-$(date +%Y%m%d-%H%M%S)"

    echo -e "${YELLOW}→ Đang tạo backup...${NC}"
    cp "$binary_path" "$backup_path"
    echo -e "  Backup: ${BLUE}$backup_path${NC}"

    echo -e "${YELLOW}→ Đang áp dụng patch...${NC}"

    python3 - "$binary_path" "$PATCH_MARKER" << 'PYTHON_EOF'
import sys

binary_path = sys.argv[1]
patch_marker = sys.argv[2]

with open(binary_path, 'rb') as f:
    content = bytearray(f.read())

original_size = len(content)

# Pattern for Claude Code v2.1.17 (237 bytes)
# This is the buggy code that only deletes backspace chars without preserving actual input
original_block = b'if(!e.backspace&&!e.delete&&n.includes("\\x7F")){let CT=(n.match(/\\x7f/g)||[]).length,ZT=y;for(let IT=0;IT<CT;IT++)ZT=ZT.deleteTokenBefore()??ZT.backspace();if(!y.equals(ZT)){if(y.text!==ZT.text)R(ZT.text);b(ZT.offset)}n_A(),a_A();return}'

# Fixed code that handles Vietnamese IME correctly (221 bytes before padding)
# This properly:
# 1. Counts backspace chars (\x7f) 
# 2. Deletes them from cursor
# 3. Inserts the actual character inputs (after removing \x7f)
fixed_code = b'if(!e.backspace&&!e.delete&&n.includes("\\x7F")){let C=n.split("\\x7f").length-1,Z=y;while(C--)Z=Z.deleteTokenBefore()??Z.backspace();for(let c of n.replace(/\\x7f/g,""))Z=Z.insert(c);R(Z.text);b(Z.offset);n_A(),a_A();return'

padding_needed = len(original_block) - len(fixed_code) - 1
marker_comment = f'/*{patch_marker}*/'.encode()
extra_padding = padding_needed - len(marker_comment)
if extra_padding < 0:
    print("ERROR: Marker too long")
    sys.exit(1)

fixed_padded = fixed_code + marker_comment + b' ' * extra_padding + b'}'

if len(original_block) != len(fixed_padded):
    print(f"ERROR: Length mismatch: {len(original_block)} vs {len(fixed_padded)}")
    sys.exit(1)

if patch_marker.encode() in content:
    print("ALREADY_PATCHED")
    sys.exit(0)

idx = content.find(original_block)
count = 0
while idx != -1:
    count += 1
    content[idx:idx+len(original_block)] = fixed_padded
    idx = content.find(original_block, idx + 1)

if count == 0:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

with open(binary_path, 'wb') as f:
    f.write(content)

new_size = len(content)
if original_size != new_size:
    print("SIZE_CHANGED")
    sys.exit(1)

print(f"SUCCESS:{count}")
PYTHON_EOF

    local result=$?
    local output=$(python3 -c "
import sys
marker = '$PATCH_MARKER'
with open('$binary_path', 'rb') as f:
    content = f.read()
if marker.encode() in content:
    print('PATCHED')
else:
    print('NOT_PATCHED')
")

    if [[ "$output" != "PATCHED" ]]; then
        echo -e "${RED}✗ Patch thất bại!${NC}"
        echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
        cp "$backup_path" "$binary_path"
        return 1
    fi

    echo -e "${YELLOW}→ Đang re-sign binary...${NC}"
    codesign --remove-signature "$binary_path" 2>/dev/null || true
    if ! codesign -s - -f "$binary_path" 2>/dev/null; then
        echo -e "${RED}✗ Re-sign thất bại!${NC}"
        echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
        cp "$backup_path" "$binary_path"
        return 1
    fi

    echo -e "${YELLOW}→ Đang kiểm tra binary...${NC}"
    if ! "$binary_path" --version &> /dev/null; then
        echo -e "${RED}✗ Binary không chạy được sau khi patch!${NC}"
        echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
        cp "$backup_path" "$binary_path"
        return 1
    fi

    return 0
}

restore_backup() {
    local binary_path="$1"

    local backup_dir=$(dirname "$binary_path")
    local binary_name=$(basename "$binary_path")
    local latest_backup=$(ls -t "${binary_path}.backup-"* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        echo -e "${RED}✗ Không tìm thấy file backup.${NC}"
        echo -e "  Bạn có thể cài lại Claude Code:"
        echo -e "  ${GREEN}brew reinstall --cask claude-code${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ Tìm thấy backup: ${BLUE}$latest_backup${NC}"
    echo -e "${YELLOW}→ Đang khôi phục...${NC}"

    cp "$latest_backup" "$binary_path"

    codesign --remove-signature "$binary_path" 2>/dev/null || true
    codesign -s - -f "$binary_path" 2>/dev/null || true

    if "$binary_path" --version &> /dev/null; then
        echo -e "${GREEN}✓ Đã khôi phục thành công!${NC}"
        rm -f "$latest_backup"
        echo -e "  Đã xóa backup: $latest_backup"
    else
        echo -e "${RED}✗ Khôi phục thất bại!${NC}"
        echo -e "  Vui lòng cài lại: ${GREEN}brew reinstall --cask claude-code${NC}"
        return 1
    fi
}

list_backups() {
    local binary_path="$1"
    local backups=$(ls -t "${binary_path}.backup-"* 2>/dev/null)

    if [[ -z "$backups" ]]; then
        echo -e "${YELLOW}Không có backup nào.${NC}"
        return
    fi

    echo -e "${BLUE}Danh sách backup:${NC}"
    echo "$backups" | while read -r backup; do
        local size=$(ls -lh "$backup" | awk '{print $5}')
        local date=$(echo "$backup" | grep -o '[0-9]\{8\}-[0-9]\{6\}')
        echo -e "  - $backup (${size})"
    done
}

main() {
    local action="${1:-patch}"

    echo -e "${YELLOW}→ Đang tìm Claude Code binary...${NC}"

    BINARY_PATH=$(find_binary)

    if [[ -z "$BINARY_PATH" ]] || [[ ! -f "$BINARY_PATH" ]]; then
        echo -e "${RED}✗ Không tìm thấy Claude Code binary.${NC}"
        echo ""
        echo -e "  Script này chỉ hỗ trợ bản binary (Homebrew/native installer)."
        echo -e "  Nếu bạn cài qua npm, hãy dùng script khác: fix-vietnamese-input.sh"
        exit 1
    fi

    echo -e "  Đường dẫn: ${BLUE}$BINARY_PATH${NC}"
    echo -e "  Phiên bản: ${BLUE}$(get_version)${NC}"

    if ! file "$BINARY_PATH" | grep -q "Mach-O"; then
        echo -e "${RED}✗ File không phải là Mach-O binary.${NC}"
        echo -e "  Có vẻ bạn đang dùng bản npm. Hãy dùng script khác: fix-vietnamese-input.sh"
        exit 1
    fi

    echo ""

    case "$action" in
        patch|fix|apply)
            if is_patched "$BINARY_PATH"; then
                echo -e "${GREEN}✓ Binary đã được patch trước đó.${NC}"
                exit 0
            fi

            echo -e "${YELLOW}⚠️  Bạn có chắc muốn patch binary không?${NC}"
            echo -e "   Nhấn Enter để tiếp tục, Ctrl+C để hủy..."
            read -r

            if apply_patch "$BINARY_PATH"; then
                echo ""
                echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║  ✓ Patch thành công! Vietnamese IME fix đã được áp dụng.      ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "Vui lòng ${YELLOW}khởi động lại Claude Code${NC} để áp dụng thay đổi."
                echo ""
                echo -e "${YELLOW}Lưu ý:${NC}"
                echo -e "  - Binary đã được re-sign với ad-hoc signature"
                echo -e "  - Nếu gặp lỗi, chạy: ${GREEN}$0 restore${NC}"
                echo ""
            else
                echo ""
                echo -e "${RED}✗ Patch thất bại!${NC}"
                echo -e "  Code structure có thể đã thay đổi trong phiên bản mới."
                exit 1
            fi
            ;;

        unpatch|remove|restore)
            echo -e "${YELLOW}→ Đang khôi phục binary gốc...${NC}"
            if restore_backup "$BINARY_PATH"; then
                echo -e "${GREEN}✓ Đã khôi phục Claude Code về bản gốc.${NC}"
            else
                exit 1
            fi
            ;;

        status|check)
            echo -e "${YELLOW}→ Kiểm tra trạng thái patch...${NC}"
            echo ""

            if is_patched "$BINARY_PATH"; then
                echo -e "  Trạng thái: ${GREEN}✓ Đã patch${NC}"
            else
                echo -e "  Trạng thái: ${RED}✗ Chưa patch${NC}"
            fi

            local sig_status=$(codesign -dvv "$BINARY_PATH" 2>&1 | grep -i "signature" | head -1)
            echo -e "  Signature: ${BLUE}$sig_status${NC}"

            echo ""
            list_backups "$BINARY_PATH"
            ;;

        list-backups|backups)
            list_backups "$BINARY_PATH"
            ;;

        *)
            echo "Usage: $0 [patch|restore|status|list-backups]"
            echo ""
            echo "Commands:"
            echo "  patch        - Áp dụng Vietnamese IME fix (default)"
            echo "  restore      - Khôi phục binary gốc từ backup"
            echo "  status       - Kiểm tra trạng thái patch"
            echo "  list-backups - Liệt kê các file backup"
            exit 1
            ;;
    esac
}

main "$@"
