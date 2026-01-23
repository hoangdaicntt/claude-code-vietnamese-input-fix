# Changelog - Claude Code Vietnamese IME Fix

## Version 2.1.17 (2026-01-23) - FIXED

### 🎯 Cập nhật quan trọng
- **✅ Đã fix hoàn toàn**: Pattern matching chính xác cho phiên bản 2.1.17
- **Hỗ trợ Claude Code v2.1.17**: Cập nhật pattern từ 241 bytes (v2.1.15) xuống 237 bytes (v2.1.17)
- **Tự động phát hiện vị trí binary mới**: Script giờ đây tìm binary ở `~/.local/share/claude/versions/` (vị trí mới từ v2.1.17+)

### 📝 Chi tiết kỹ thuật

#### Pattern đã được xác định chính xác
**v2.1.17 (237 bytes):**
```javascript
if(!e.backspace&&!e.delete&&n.includes("\x7F")){
  let CT=(n.match(/\x7f/g)||[]).length,ZT=y;
  for(let IT=0;IT<CT;IT++)ZT=ZT.deleteTokenBefore()??ZT.backspace();
  if(!y.equals(ZT)){if(y.text!==ZT.text)R(ZT.text);b(ZT.offset)}
  n_A(),a_A();return
}
```

**Fixed code (221 bytes + padding):**
```javascript
if(!e.backspace&&!e.delete&&n.includes("\x7F")){
  let C=n.split("\x7f").length-1,Z=y;
  while(C--)Z=Z.deleteTokenBefore()??Z.backspace();
  for(let c of n.replace(/\x7f/g,""))Z=Z.insert(c);
  R(Z.text);b(Z.offset);n_A(),a_A();return
  /*PHTV_FIX*/   
}
```

#### Sự khác biệt với v2.1.15:
| Thuộc tính | v2.1.15 | v2.1.17 |
|------------|---------|---------|
| Pattern size | 241 bytes | 237 bytes |
| Event var | `AT` | `e` |
| Input var | `p` | `n` |
| Count var | `WT` | `CT` |
| Temp cursor | `QT` | `ZT` |
| Iterator | `NT` | `IT` |
| Set offset fn | `w()` | `b()` |
| Function 1 | `neR()` | `n_A()` |
| Function 2 | `aeR()` | `a_A()` |

#### Thông tin patch:
- Pattern xuất hiện **2 lần** trong binary (offset: 67436096, 161155460)
- Giữ nguyên kích thước binary: 180,604,400 bytes
- Marker: `/*PHTV_FIX*/` với 3 spaces padding

### 🔍 Cách tìm binary

Script sẽ tìm binary theo thứ tự:

1. **`~/.local/share/claude/versions/<version>` (Mới)** - Vị trí mặc định từ v2.1.17+
2. `/opt/homebrew/bin/claude` - Homebrew symlink  
3. `/usr/local/bin/claude` - Homebrew fallback
4. `/opt/homebrew/Caskroom/claude-code/*/claude` - Homebrew Cask
5. `which claude` - System PATH

### ⚙️ Cách sử dụng

```bash
# Kiểm tra trạng thái
./fix-vietnamese-input-binary.sh status

# Áp dụng patch
./fix-vietnamese-input-binary.sh patch

# Khôi phục bản gốc
./fix-vietnamese-input-binary.sh restore
```

### 🐛 Known Issues
- ✅ **FIXED**: Pattern matching giờ hoạt động chính xác với v2.1.17
- Mỗi khi Claude Code cập nhật phiên bản mới, pattern có thể thay đổi
- Script chỉ hoạt động với bản binary (native installer), không hỗ trợ npm version

### 📌 Notes
- Patch giữ nguyên size của binary để tránh làm hỏng cấu trúc
- Binary sẽ được re-sign với ad-hoc signature sau khi patch
- Luôn tạo backup trước khi patch

---

## Version 2.1.15 (Initial Release)

- Phát hành ban đầu hỗ trợ Claude Code v2.1.15
- Fix Vietnamese IME input issue với binary patching
