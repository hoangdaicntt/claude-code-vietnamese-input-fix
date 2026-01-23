# Auto-Detection Tool for Vietnamese IME Pattern

Script `auto-detect-pattern.sh` tự động phát hiện và phân tích pattern Vietnamese IME trong các phiên bản mới của Claude Code.

## Mục đích

Khi Claude Code cập nhật phiên bản mới, minification có thể thay đổi tên biến, làm cho pattern cần patch khác đi. Script này giúp:

1. ✅ Tự động tìm pattern Vietnamese IME trong binary
2. ✅ Phát hiện tên biến đã thay đổi
3. ✅ Tự động generate fixed code với padding chính xác
4. ✅ Cung cấp code ready-to-use để update patch script

## Cách sử dụng

```bash
./auto-detect-pattern.sh
```

## Kết quả

Script sẽ output:

### 1. Pattern Information
- Offset trong binary
- Độ dài pattern (bytes)
- Raw bytes và decoded text
- Số vị trí xuất hiện trong binary

### 2. Variable Analysis
```
Event object: e
Input string: n  
Count variable: CT
Temp cursor: ZT
Iterator: IT
Offset function: b()
Ending functions: n_A(), a_A()
```

### 3. Generated Fix Code
```python
original_block = b'if(!e.backspace&&!e.delete&&n.includes...'
fixed_code = b'if(!e.backspace&&!e.delete&&n.includes...'
```

## Khi nào sử dụng

- ✅ Claude Code vừa cập nhật phiên bản mới
- ✅ Patch hiện tại báo lỗi "PATTERN_NOT_FOUND"
- ✅ Muốn verify pattern cho phiên bản hiện tại

## Lưu ý

1. **Binary đã patch**: Script sẽ phát hiện và yêu cầu dùng backup file
2. **Backup tự động**: Script tự động tìm backup file gần nhất
3. **Manual verification**: Luôn test patch trên backup trước khi áp dụng

## Output Example

```
✓ Pattern detected successfully!
  Offset: 67436096
  Length: 237 bytes
  Found at 2 location(s)

✓ Fixed code:
  if(!e.backspace&&!e.delete&&n.includes("\x7F")){...
  
  Fixed length: 221 bytes
  Original length: 237 bytes
  Padding needed: 15 bytes
  ✅ Length match! 237 == 237

🎉 SUCCESS! Auto-detection complete.
```

## Workflow khi có phiên bản mới

1. Chạy auto-detect script:
   ```bash
   ./auto-detect-pattern.sh
   ```

2. Copy `original_block` và `fixed_code` từ output

3. Update `fix-vietnamese-input-binary.sh`:
   ```python
   # Thay thế 2 dòng này với giá trị mới
   original_block = b'...'
   fixed_code = b'...'
   ```

4. Test với backup:
   ```bash
   # Dry-run test
   python3 -c "..." 
   ```

5. Áp dụng patch:
   ```bash
   ./fix-vietnamese-input-binary.sh patch
   ```

6. Commit changes và update CHANGELOG.md

## Technical Details

Script sử dụng pattern matching để tìm:
- Characteristic string: `.includes("\x7F")`
- Bounding markers: `if(!` ... `return}`
- Validation: Phải chứa `backspace`, `delete`, `deleteTokenBefore`

Sau đó parse variable names bằng regex và generate fixed code tự động.
