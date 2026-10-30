# Hướng dẫn Khắc phục Lỗi Đăng nhập SSH sau khi Hardening

Tài liệu này ghi chú lại quá trình xử lý lỗi không thể đăng nhập SSH bằng tài khoản thường (`hungnv1`) sau khi thực hiện các bước bảo mật (Hardening) hệ thống Linux (Ubuntu).

## Bước 1: Xác định nguyên nhân
*   **Lỗi gốc:** Việc thay đổi quyền sở hữu của file `/etc/shadow` thành `root:root` (Mục 6.1.2 trong tài liệu Hardening) đã tước đi quyền đọc mật khẩu của nhóm `shadow`.
*   **Hậu quả:** Hệ thống xác thực PAM (Pluggable Authentication Modules) bị "mù", không thể đọc mật khẩu mã hóa để đối chiếu, dẫn đến từ chối đăng nhập mọi tài khoản thường.
*   **Hệ lụy đi kèm:** Do cấu hình `pam_faillock.so` (Mục 5.3.2), việc hệ thống liên tục báo sai mật khẩu đã kích hoạt cơ chế khóa tài khoản (faillock) đối với `hungnv1`.

## Bước 2: Truy cập Web Console và vào chế độ GRUB Edit
Do SSH đã bị chặn với cả `hungnv1` (lỗi PAM) và `root` (cấu hình `PermitRootLogin no`), cách duy nhất là can thiệp vật lý ảo:
1. Đăng nhập vào trang quản trị VNPT Cloud.
2. Mở giao diện Web Console (noVNC) của máy ảo.
3. Nếu máy đang treo hoặc ở màn hình đăng nhập, tiến hành **Khởi động lại (Restart)** VM từ trang quản trị.
4. Ngay khi máy vừa boot, nhấn liên tục phím `Esc` hoặc `Shift` để gọi màn hình menu **GNU GRUB**.
5. Tại dòng đầu tiên (`*Ubuntu`), nhấn phím **`e`** để vào chế độ chỉnh sửa (Edit mode).

## Bước 3: Can thiệp mã khởi động để vào Root Shell (Bypass Password)
Trong màn hình chỉnh sửa mã GRUB, sử dụng phím mũi tên để tìm đến dòng bắt đầu bằng chữ `linux`. Di chuyển con trỏ đến tận cùng của dòng này và thực hiện sửa đổi (xóa chữ `ro`, giữ nguyên `console=tty1` và thêm `rw init=/bin/bash`).

**Dòng lệnh `linux` HOÀN CHỈNH sau khi chỉnh sửa sẽ trông như thế này:**

```text
linux        /boot/vmlinuz-5.15.0-198-generic root=UUID=b0100f5a-9690-4879-b6b3-9dea484f878d net.ifnames=0 biosdevname=0 console=tty1 rw init=/bin/bash
```

*(Lưu ý: Dấu gạch chéo ngược `\` ở cuối màn hình hiển thị chỉ là ký hiệu tự động ngắt dòng của trình soạn thảo, không ảnh hưởng đến cấu trúc lệnh, nhưng bắt buộc phải có **dấu cách** trước chữ `net` và trước chữ `rw`)*.

Sau khi đảm bảo dòng lệnh đã chính xác, nhấn **`Ctrl + X`** (hoặc **`F10`**) để khởi động thẳng vào hệ điều hành dưới quyền Root tối cao mà không cần mật khẩu.

## Bước 4: Sửa lỗi file shadow và mở khóa tài khoản
Ngay khi màn hình đen xuất hiện dấu nhắc lệnh `root@(none):/#`, thực hiện gõ các lệnh sau để khôi phục quyền sở hữu cho file mật khẩu:

```bash
# 1. Trả lại quyền sở hữu cho group shadow
chown root:shadow /etc/shadow
chown root:shadow /etc/gshadow

# 2. Cấp quyền đọc cho group shadow
chmod 640 /etc/shadow
chmod 640 /etc/gshadow
```

Tiếp theo, chạy lệnh sau để xóa lịch sử nhập sai mật khẩu và mở khóa cho tài khoản `hungnv1`:

```bash
/usr/sbin/faillock --user hungnv1 --reset
```

## Bước 5: Khởi động lại VM và truy cập bình thường
1. Do hệ thống đang ở môi trường rút gọn (chưa mount đủ service), lệnh reboot đôi khi không hoạt động. Cách nhanh nhất là quay lại trang quản trị VNPT Cloud và nhấn nút **Khởi động lại (Restart / Hard Reset)** máy ảo một lần nữa.
2. Mở phần mềm SSH (PuTTY, MobaXterm, Termius,...) lên.
3. Tiến hành đăng nhập SSH bằng tài khoản `hungnv1`.
4. Hệ thống sẽ xác thực thành công và cho phép truy cập.