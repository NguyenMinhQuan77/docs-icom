# Hướng dẫn tạo Alias (Cấu hình SSH nhanh) trên Jump Server .85

Do bạn đang làm việc trực tiếp trên con `.85` và sử dụng user `quannm` để nhảy sang các con `.71`, `.223` (port 2223), bạn hãy làm theo các bước sau để mỗi lần gõ lệnh được nhanh và nhàn nhất.

## Bước 1: Tạo và chỉnh sửa file SSH Config trên con .85

Đứng trên máy **.85** (đang dùng user `root`), bạn chạy lệnh sau để mở (hoặc tạo mới) file cấu hình SSH của client:

```bash
nano ~/.ssh/config
```

## Bước 2: Thêm thông tin danh bạ các server

Dán nội dung sau vào file vừa mở:

```text
# --- Cấu hình nhảy sang DB Server (.71) ---
Host db71
    HostName 192.168.78.71
    User quannm
    Port 2223

# --- Cấu hình nhảy sang App Server (.223) ---
Host app223
    HostName 192.168.78.223
    User quannm
    Port 2223
```

*(Lưu ý: Tôi sử dụng IP LAN `192.168.78.x` thay vì IP Public để kết nối nội bộ cho nhanh, an toàn và không tốn băng thông ra ngoài Internet. Nếu 3 máy này không thông mạng LAN, bạn hãy đổi lại thành IP Public `59.153.245.x` tương ứng nhé).*

Lưu file lại (Trong Nano: nhấn `Ctrl+O` -> `Enter` -> `Ctrl+X`).

## Bước 3: Phân quyền cho file config (Quan trọng)

Để bảo mật, SSH yêu cầu file config này chỉ chủ sở hữu mới được đọc/ghi. Chạy lệnh:

```bash
chmod 600 ~/.ssh/config
```

## Bước 4: Tận hưởng kết quả

Bây giờ, thay vì phải gõ câu lệnh dài ngoằng:
`ssh -p 2223 quannm@192.168.78.71`

Từ trên con **.85**, bạn chỉ cần gõ:
```bash
ssh db71
```
Hoặc:
```bash
ssh app223
```

Hệ thống sẽ tự động dùng Key đã copy từ trước, sử dụng tài khoản `quannm`, kết nối vào đúng port `2223` và đưa bạn vào thẳng server đích!