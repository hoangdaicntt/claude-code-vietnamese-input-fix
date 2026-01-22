# Claude Code Vietnamese Input Fix

Công cụ sửa lỗi gõ tiếng Việt trong Claude Code CLI.

## Vấn đề

Claude Code CLI có lỗi khi gõ tiếng Việt với bộ gõ (IME):
- Các ký tự tiếng Việt bị mất khi gõ
- Chỉ hiển thị ký tự backspace (DEL 0x7F) nhưng không chèn ký tự thay thế

## Giải pháp

Script này tự động patch file `cli.js` (bản npm) hoặc binary (bản Homebrew) của Claude Code để sửa lỗi gõ tiếng Việt.

## Cài đặt và sử dụng

### Cài đặt nhanh với curl (khuyến khích)

**Bản npm:**
```bash
curl -fsSL https://raw.githubusercontent.com/hoangdaicntt/claude-code-vietnamese-input-fix/main/fix-vietnamese-input.sh | bash
```

**Bản binary (Homebrew):**
```bash
curl -fsSL https://raw.githubusercontent.com/hoangdaicntt/claude-code-vietnamese-input-fix/main/fix-vietnamese-input-binary.sh | bash
```

### Cài đặt thủ công

Tải về repository và chạy script:

```bash
git clone https://github.com/hoangdaicntt/claude-code-vietnamese-input-fix.git
cd claude-code-vietnamese-input-fix
chmod +x fix-vietnamese-input.sh fix-vietnamese-input-binary.sh

# Bản npm
./fix-vietnamese-input.sh

# Bản binary (Homebrew)
./fix-vietnamese-input-binary.sh
```

## Các lệnh hỗ trợ

### Kiểm tra trạng thái patch

```bash
./fix-vietnamese-input.sh status
```

### Gỡ patch (khôi phục về bản gốc)

```bash
./fix-vietnamese-input.sh unpatch
```

### Liệt kê file backup (chỉ bản binary)

```bash
./fix-vietnamese-input-binary.sh list-backups
```

## Yêu cầu hệ thống

- macOS hoặc Linux
- Claude Code đã được cài đặt
- Python 3 (đã có sẵn trên hầu hết hệ thống)
- Bash

## Cách hoạt động

Script sẽ:
1. Tìm file `cli.js` hoặc binary của Claude Code
2. Tạo file backup tự động với timestamp
3. Patch code để xử lý đúng ký tự tiếng Việt từ bộ gõ IME
4. Xác minh patch đã được áp dụng thành công

## Sử dụng với curl | bash

Script được thiết kế để chạy an toàn với curl pipe bash:

```bash
# Kiểm tra nội dung script trước khi chạy
curl -fsSL https://raw.githubusercontent.com/hoangdaicntt/claude-code-vietnamese-input-fix/main/fix-vietnamese-input.sh

# Chạy trực tiếp (tự động patch)
curl -fsSL https://raw.githubusercontent.com/hoangdaicntt/claude-code-vietnamese-input-fix/main/fix-vietnamese-input.sh | bash

# Hoặc tải về rồi chạy
curl -fsSL -o fix-vietnamese-input.sh https://raw.githubusercontent.com/hoangdaicntt/claude-code-vietnamese-input-fix/main/fix-vietnamese-input.sh
chmod +x fix-vietnamese-input.sh
./fix-vietnamese-input.sh
```

## Lưu ý

- Script tự động tạo backup trước khi patch
- Có thể khôi phục về bản gốc bất cứ lúc nào với lệnh `unpatch`
- Sau khi patch, khởi động lại Claude Code để áp dụng thay đổi
- Bản binary được re-sign với ad-hoc signature

## Báo lỗi

Nếu gặp vấn đề, vui lòng tạo issue tại [GitHub Issues](https://github.com/hoangdaicntt/claude-code-vietnamese-input-fix/issues)

## Giấy phép

MIT License
