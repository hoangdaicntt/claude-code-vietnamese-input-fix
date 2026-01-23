# Claude Code Vietnamese Input Fix

Công cụ sửa lỗi gõ tiếng Việt trong Claude Code CLI.

## ✅ Phiên bản hỗ trợ

- **Claude Code v2.1.17** (Latest) ✅
- Claude Code v2.1.15 ✅

## Vấn đề

Claude Code CLI có lỗi khi gõ tiếng Việt với bộ gõ (IME):
- Các ký tự tiếng Việt bị mất khi gõ
- Chỉ hiển thị ký tự backspace (DEL 0x7F) nhưng không chèn ký tự thay thế

## 🚀 Cài đặt (1 lệnh)

### Cài đặt nhanh với curl

```bash
curl -fsSL https://raw.githubusercontent.com/hoangdaicntt/claude-code-vietnamese-input-fix/main/patch.sh | bash
```

### Hoặc clone repository

```bash
git clone https://github.com/hoangdaicntt/claude-code-vietnamese-input-fix.git
cd claude-code-vietnamese-input-fix
./patch.sh
```

Script tự động:
- ✅ Phát hiện pattern Vietnamese IME
- ✅ Generate fixed code
- ✅ Apply patch
- ✅ Verify và re-sign binary

## Yêu cầu hệ thống

- macOS hoặc Linux
- Claude Code đã được cài đặt
- Python 3 (đã có sẵn trên hầu hết hệ thống)
- Bash

## Lưu ý

- Script tự động tạo backup trước khi patch
- Sau khi patch, khởi động lại Claude Code để áp dụng thay đổi
- Bản binary được re-sign với ad-hoc signature

## 🔧 Cho maintainers

Xem [AUTO-PATCH.md](AUTO-PATCH.md) để biết chi tiết về auto-patch tool.

## Báo lỗi

Nếu gặp vấn đề, vui lòng tạo issue tại [GitHub Issues](https://github.com/hoangdaicntt/claude-code-vietnamese-input-fix/issues)

## Giấy phép

MIT License
