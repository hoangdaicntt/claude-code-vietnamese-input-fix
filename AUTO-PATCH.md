# Auto-Patch Script - One-Command Solution

Script `patch.sh` là giải pháp **hoàn toàn tự động** - chỉ cần 1 lệnh duy nhất để patch Claude Code cho mọi phiên bản!

## 🚀 Quick Start

```bash
./patch.sh
```

Đó là tất cả! Script sẽ tự động:
1. ✅ Tìm Claude Code binary
2. ✅ Phát hiện pattern Vietnamese IME
3. ✅ Generate fixed code
4. ✅ Tạo backup
5. ✅ Apply patch
6. ✅ Re-sign binary
7. ✅ Verify patch hoạt động

## 🎯 Tính năng

### Hoàn toàn tự động
- **Không cần config**: Script tự detect mọi thứ
- **Không cần biết phiên bản**: Hoạt động với bất kỳ version nào
- **Không cần update script**: Pattern được detect runtime

### An toàn
- Tự động tạo backup trước khi patch
- Verify binary sau patch
- Auto-rollback nếu có lỗi
- Detect nếu đã được patch trước đó

### Thông minh
- Parse variable names từ minified code
- Generate correct padding automatically
- Support multiple pattern locations
- Error handling đầy đủ

## 📋 Output Example

```
╔════════════════════════════════════════════════════════════════╗
║  Claude Code Vietnamese IME Fix - AUTO PATCH                   ║
║  Auto-detect pattern and apply patch automatically             ║
╚════════════════════════════════════════════════════════════════╝

→ Đang tìm Claude Code binary...
  Đường dẫn: /Users/xxx/.local/share/claude/versions/2.1.17
  Phiên bản: 2.1.17 (Claude Code)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BƯỚC 1: AUTO-DETECT PATTERN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

→ Đang phân tích binary để tìm pattern...
✓ Đã phát hiện pattern!
  Độ dài: 237 bytes
  Xuất hiện: 2 vị trí

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BƯỚC 2: APPLY PATCH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Bạn có muốn áp dụng patch không?
   Phiên bản: 2.1.17 (Claude Code)
   Binary: /Users/xxx/.local/share/claude/versions/2.1.17

   Nhấn Enter để tiếp tục, Ctrl+C để hủy...

→ Đang tạo backup...
→ Đang áp dụng patch...
✓ Patch áp dụng thành công tại 2 vị trí
→ Đang re-sign binary...
→ Đang kiểm tra binary...

╔════════════════════════════════════════════════════════════════╗
║  ✓ PATCH THÀNH CÔNG!                                          ║
║  Vietnamese IME fix đã được áp dụng tự động.                   ║
╚════════════════════════════════════════════════════════════════╝

📋 Thông tin:
   Phiên bản: 2.1.17 (Claude Code)
   Pattern: 237 bytes tại 2 vị trí
   Backup: /Users/xxx/.local/share/claude/versions/2.1.17.backup-xxx

⚠️  Vui lòng khởi động lại Claude Code để áp dụng thay đổi.
```

## 🔧 Technical Details

### Bước 1: Auto-Detection
```python
# Tìm pattern trong binary
search_key = b'.includes("\\x7F")'

# Validate structure
if_pattern = b'if(!'
return_pattern = b'return}'

# Parse variable names bằng regex
event_var = regex.search(r'if\(!(\w+)\.backspace...')
input_var = ...
offset_func = ...
```

### Bước 2: Code Generation
```python
# Generate fixed code với correct variable names
fixed = f'if(!{event}.backspace&&!{event}.delete&&{input}.includes...'

# Calculate exact padding
padding = original_length - fixed_length - 1
fixed_padded = fixed + marker + spaces + '}'
```

### Bước 3: Binary Patching
```python
# Replace all occurrences
while idx != -1:
    content[idx:idx+len(original)] = fixed_padded
    idx = content.find(original, idx + 1)
```

## ⚠️ Error Handling

Script handles các trường hợp:

**NO_PATTERN**: Không tìm thấy Vietnamese IME code
```
→ Claude version might not have the bug
→ Or code structure changed completely  
```

**CANNOT_PARSE_VARS**: Không parse được variable names
```
→ Code minification changed significantly
→ Use manual method: auto-detect-pattern.sh
```

**PATTERN_NOT_FOUND**: Pattern không match trong binary
```
→ Should never happen after auto-detect
→ Contact maintainer if this occurs
```

**ALREADY_PATCHED**: Binary đã được patch
```
✓ Binary đã được patch rồi!
  Không cần patch lại.
```

## 🆚 So sánh với các script khác

| Feature | patch.sh | patch-binary.sh | detect.sh |
|---------|----------|-----------------|-----------|
| Tự động detect pattern | ✅ | ❌ (hardcoded) | ✅ |
| Tự động apply patch | ✅ | ✅ | ❌ (chỉ analyze) |
| Cần update khi version mới | ❌ | ✅ | ❌ |
| Số bước thực hiện | 1 | 1 | 2 (manual copy) |
| Dành cho | End users | Maintainers | Maintainers |

## 🎯 Use Cases

### End Users (Recommended)
```bash
# Chỉ cần 1 lệnh duy nhất
./patch.sh
```

### Maintainers/Developers
```bash
# Khi cần xem chi tiết pattern
./detect.sh

# Khi muốn dùng hardcoded pattern (faster)
./patch-binary.sh patch
```

## 🔄 Rollback

Nếu cần rollback:
```bash
./patch-binary.sh restore
```

## 📝 Notes

- Script yêu cầu Python 3 (built-in trên macOS)
- Chỉ hỗ trợ Mach-O binary (macOS/Linux native)
- Không hỗ trợ npm version
- Backup được tạo tự động, không bị overwrite

## 🚀 Future-Proof

Script này được thiết kế để hoạt động với **mọi phiên bản tương lai** của Claude Code (miễn là bug vẫn còn và code structure tương tự).

Không cần:
- ❌ Update script khi có version mới
- ❌ Hardcode pattern cho từng version
- ❌ Manual analysis binary

Chỉ cần:
- ✅ Run `./patch.sh`
- ✅ Done!
