# Hướng dẫn Setup Jump Server (.85) Quản trị Nội Bộ

**Thông tin hệ thống:**
*   **Jump Server (.85):** IP Public `59.153.245.167`, IP LAN `192.168.78.85`
*   **App Server (.223):** IP Public `59.153.245.168`, IP LAN `192.168.78.223` (Port SSH: 2223)
*   **DB Server (.71):** IP Public `59.153.245.236`, IP LAN `192.168.78.71` (Port SSH: 2223)

Mục tiêu: Đăng nhập vào `.85`, từ `.85` mới SSH được vào `.223` và `.71` bằng quyền `root`. Khóa chặt `.223` và `.71` không cho ai kết nối trực tiếp từ bên ngoài.

---

## BƯỚC 1: Tạo SSH Key trên Jump Server (.85)

SSH vào máy **.85** bằng quyền `root` (thông qua IP Public `59.153.245.167`), sau đó chạy:

```bash
# Tạo khóa SSH (cứ nhấn Enter cho mọi câu hỏi)
ssh-keygen -t ed25519 -C "root-jump-85"
```

Tiếp theo, đẩy khóa này sang `.71` và `.223` thông qua user `quannm` (vì root đang bị khóa pass):

```bash
# Đẩy key sang .223
ssh-copy-id -p 2223 quannm@59.153.245.168

# Đẩy key sang .71
ssh-copy-id -p 2223 quannm@59.153.245.236
```
*(Bạn cần nhập pass của quannm ở bước này).*

---

## BƯỚC 2: Khôi phục quyền Root trên các Target (.223 và .71)

Từ máy `.85`, bạn SSH sang `.223` bằng user `quannm`:

```bash
ssh -p 2223 quannm@59.153.245.168
```

Khi đã vào được `.223`, chuyển sang `root`:
```bash
sudo su -
```

Bây giờ copy Public Key từ quannm sang root để root cũng nhận key từ con .85:
```bash
mkdir -p /root/.ssh
cat /home/quannm/.ssh/authorized_keys >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

Sửa cấu hình SSH để cho phép root dùng key:
```bash
nano /etc/ssh/sshd_config
```
Tìm dòng `PermitRootLogin no` sửa thành `PermitRootLogin prohibit-password`.

Cuộn xuống cuối file, thêm giới hạn chỉ cho IP con .85 vào:
```text
Match Address 59.153.245.167,192.168.78.85
    AllowUsers root
```
Lưu lại và restart SSH:
```bash
systemctl restart ssh
```

*(Lặp lại toàn bộ Bước 2 này cho con DB .71 - IP 59.153.245.236)*

---

## BƯỚC 3: Dùng Firewall (UFW) khóa chặt .223 và .71

Đây là bước quan trọng nhất để **cấm toàn bộ Internet** chọc vào cổng 2223 của con .223 và .71, ngoại trừ con .85.

Vẫn đứng bằng quyền `root` trên `.223` (và sau đó làm tương tự trên `.71`), chạy các lệnh sau:

```bash
# Cho phép IP Public của con .85 vào port 2223
ufw allow from 59.153.245.167 to any port 2223

# Cho phép IP LAN của con .85 vào port 2223 (đề phòng mượn đường LAN)
ufw allow from 192.168.78.85 to any port 2223

# Xóa các rule ufw đang mở toang port 2223 (do script hardening tạo ra)
ufw delete allow 2223/tcp

# Chặn toàn bộ IP khác truy cập port 2223
ufw deny 2223/tcp

# Tải lại tường lửa
ufw reload
```

---

## BƯỚC 4: Cách sử dụng hàng ngày

Từ bây giờ, không ai trên Internet có thể chọc thẳng vào IP Public của `.223` và `.71` được nữa (sẽ bị timeout ngay lập tức).

Để quản trị, bạn thực hiện 2 nhịp:
1. Đăng nhập vào Jump Server bằng IP Public: `ssh root@59.153.245.167`
2. Từ Jump Server, gõ lệnh nhảy sang các máy kia bằng quyền root mà không cần pass:
   ```bash
   # Nhảy sang con App 223
   ssh -p 2223 root@59.153.245.168
   
   # Nhảy sang con DB 71
   ssh -p 2223 root@59.153.245.236
   ```
*(Mẹo: Bạn có thể dùng IP LAN `192.168.78.223` và `192.168.78.71` thay cho IP Public ở bước nhảy này cho tốc độ nhanh hơn, vì chúng cùng mạng LAN).*