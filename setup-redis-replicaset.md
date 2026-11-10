# Hướng dẫn thiết lập Redis Replication (Master-Replica)

Tài liệu này hướng dẫn cách cấu hình Redis Replication trên 2 server. 
* **Server Master (Node 1):** IP kết thúc bằng `.223` (Ví dụ: `192.168.1.223`)
* **Server Replica (Node 2):** IP kết thúc bằng `.71` (Ví dụ: `192.168.1.71`)

## Bước 1: Cài đặt Redis trên CẢ HAI server
Nếu bạn chưa cài đặt Redis, hãy chạy các lệnh sau trên cả server 223 và 71:

**Trên Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install redis-server -y
```

**Trên CentOS/RHEL:**
```bash
sudo yum install epel-release -y
sudo yum install redis -y
sudo systemctl enable redis
```

---

## Bước 2: Cấu hình Server Master (Server 223)

Mở file cấu hình Redis trên server `.223`:
```bash
sudo nano /etc/redis/redis.conf
# Hoặc trên CentOS: sudo nano /etc/redis.conf
```

Tìm và sửa các thông số sau:

1. **Cho phép kết nối từ bên ngoài (Bind IP):**
   Tìm dòng `bind 127.0.0.1 -::1` và sửa thành IP của server hoặc `0.0.0.0` để lắng nghe mọi IP (đảm bảo bạn có tường lửa bảo vệ).
   ```conf
   bind 0.0.0.0
   ```

2. **Tắt protected-mode (nếu cần thiết, hoặc giữ nguyên nhưng phải cấu hình mật khẩu):**
   ```conf
   protected-mode no
   ```

3. **Thiết lập mật khẩu (Rất khuyến khích):**
   Tìm `requirepass` và bỏ comment, đặt mật khẩu của bạn.
   ```conf
   requirepass your_strong_password_here
   ```
   *(Lưu ý: Nếu Master có mật khẩu, Replica cũng phải cấu hình `masterauth` khớp với mật khẩu này).*

Lưu file và khởi động lại Redis trên Master:
```bash
sudo systemctl restart redis-server
# Hoặc: sudo systemctl restart redis
```

---

## Bước 3: Cấu hình Server Replica (Server 71)

Mở file cấu hình Redis trên server `.71`:
```bash
sudo nano /etc/redis/redis.conf
```

Tìm và sửa các thông số tương tự, sau đó thêm cấu hình Replication:

1. **Bind IP (để có thể truy cập nếu cần):**
   ```conf
   bind 0.0.0.0
   ```

2. **Cấu hình Replica trỏ về Master (QUAN TRỌNG NHẤT):**
   Tìm dòng `replicaof` (hoặc `slaveof` ở các bản Redis cũ) và chỉ định IP của server 223 cùng port (mặc định 6379).
   ```conf
   replicaof <IP_CỦA_SERVER_223> 6379
   ```

3. **Cấu hình mật khẩu xác thực với Master:**
   Nếu ở Bước 2 bạn đã cài `requirepass`, hãy tìm `masterauth` và điền mật khẩu đó vào.
   ```conf
   masterauth your_strong_password_here
   ```

4. **Thiết lập mật khẩu cho chính Replica (Tùy chọn nhưng nên làm):**
   ```conf
   requirepass your_strong_password_here
   ```

Lưu file và khởi động lại Redis trên Replica:
```bash
sudo systemctl restart redis-server
```

---

## Bước 4: Cấu hình Tường lửa (Firewall)
Đảm bảo server 223 cho phép server 71 kết nối vào port **6379**.

**Nếu dùng UFW (Ubuntu):**
```bash
sudo ufw allow from <IP_CỦA_SERVER_71> to any port 6379
```

**Nếu dùng Firewalld (CentOS):**
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="<IP_CỦA_SERVER_71>" port protocol="tcp" port="6379" accept'
sudo firewall-cmd --reload
```

---

## Bước 5: Kiểm tra trạng thái Replication

Trên **Server Master (223)**, chạy lệnh sau để kiểm tra:
```bash
redis-cli -a your_strong_password_here info replication
```
**Kết quả mong đợi:**
Bạn sẽ thấy `role:master` và `connected_slaves:1`. Nó cũng sẽ liệt kê IP của server 71 ở phần `slave0`.

Trên **Server Replica (71)**, chạy lệnh:
```bash
redis-cli -a your_strong_password_here info replication
```
**Kết quả mong đợi:**
Bạn sẽ thấy `role:slave`, `master_host:<IP_SERVER_223>`, và `master_link_status:up`.

### Kiểm tra đồng bộ dữ liệu:
1. Vào Master (223): `redis-cli -a password` -> Gõ: `set test_key "Hello Replica"`
2. Vào Replica (71): `redis-cli -a password` -> Gõ: `get test_key` (Nếu trả về "Hello Replica" là thành công).