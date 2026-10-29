# Tài liệu Triển khai Keepalived (High Availability) cho MariaDB

**Thông tin Môi trường Triển khai**

* **Hệ điều hành:** Ubuntu 22.04.1 LTS (Jammy Jellyfish)
* **Master Node:** 192.168.78.71
* **Slave Node:** 192.168.78.223
* **IP VIP (Virtual IP):** 192.168.78.100 *(Thay đổi theo IP VIP thực tế được cấp)*
* **Card mạng (Interface):** ens3

## Nguyên lý hoạt động cơ bản
1. Ứng dụng (Web/App) sẽ chỉ kết nối đến **IP VIP (`192.168.78.100`)**, không kết nối trực tiếp vào `.71` hay `.223`.
2. Bình thường, Keepalived sẽ gắn IP VIP này vào con **Master (`.71`)**.
3. Keepalived sẽ liên tục kiểm tra dịch vụ MariaDB. Nếu MariaDB trên Master chết (hoặc server tắt), Keepalived lập tức rút IP VIP khỏi con Master và gắn nó sang con **Slave (`.223`)**. Ứng dụng tiếp tục hoạt động mà không cần đổi code.

---

## PHẦN 1: Cài đặt và chuẩn bị (Thực hiện trên CẢ Master và Slave)

**1. Cài đặt Keepalived**
```bash
sudo apt update
sudo apt install keepalived -y
```

**2. Cho phép giao thức VRRP qua tường lửa (Nếu có dùng UFW)**
Keepalived dùng giao thức VRRP để 2 máy "nói chuyện" với nhau. Cần mở khoá giao thức này:
```bash
sudo ufw allow vrrp
```

**3. Tạo Script kiểm tra sức khỏe MariaDB**
Keepalived cần một kịch bản để biết MariaDB còn sống hay đã chết.
Tạo file script:
```bash
sudo nano /etc/keepalived/check_mysql.sh
```

Dán nội dung sau vào:
```bash
#!/bin/bash
# Script này kiểm tra xem dịch vụ mariadb có đang chạy hay không
if systemctl is-active --quiet mariadb; then
    exit 0 # Dịch vụ sống, trả về 0
else
    exit 1 # Dịch vụ chết, trả về 1
fi
```

Lưu lại và cấp quyền thực thi cho file:
```bash
sudo chmod +x /etc/keepalived/check_mysql.sh
```

---

## PHẦN 2: Cấu hình trên Master Node (IP: 192.168.78.71)

Tạo và chỉnh sửa file cấu hình Keepalived:
```bash
sudo nano /etc/keepalived/keepalived.conf
```

Dán nội dung sau vào (Chú ý thay đổi `192.168.78.100` thành IP VIP của bạn):
```ini
global_defs {
    router_id MARIADB_MASTER
}

# Định nghĩa kịch bản kiểm tra sức khỏe
vrrp_script chk_mysql {
    script "/etc/keepalived/check_mysql.sh"
    interval 2      # Kiểm tra mỗi 2 giây
    weight -20      # Nếu script trả về lỗi (MariaDB chết), trừ đi 20 điểm Priority
}

vrrp_instance VI_1 {
    state MASTER          # Master giữ vai trò chính
    interface ens3        # Tên card mạng (bạn dùng ens3)
    virtual_router_id 51  # ID này phải giống hệt nhau trên cả 2 máy
    priority 100          # Độ ưu tiên (Master phải cao hơn Slave)
    advert_int 1          # Thời gian (giây) Master gửi tín hiệu "tôi còn sống" cho Slave

    authentication {
        auth_type PASS
        auth_pass Secret@123 # Mật khẩu giao tiếp giữa 2 node, phải giống nhau
    }

    virtual_ipaddress {
        192.168.78.100/24    # IP VIP ĐƯỢC CẤP CỦA BẠN ĐIỀN VÀO ĐÂY
    }

    track_script {
        chk_mysql         # Kích hoạt script kiểm tra đã tạo ở trên
    }
}
```

Khởi động lại Keepalived:
```bash
sudo systemctl restart keepalived
sudo systemctl enable keepalived
```

Kiểm tra xem Master đã nhận IP VIP chưa:
```bash
ip a show ens3
```
*(Bạn sẽ thấy dòng `inet 192.168.78.100/24 scope global secondary ens3` xuất hiện)*

---

## PHẦN 3: Cấu hình trên Slave Node (IP: 192.168.78.223)

Tạo file cấu hình:
```bash
sudo nano /etc/keepalived/keepalived.conf
```

Dán nội dung sau vào (Lưu ý các điểm khác biệt ở `state`, `priority` và `router_id`):
```ini
global_defs {
    router_id MARIADB_SLAVE
}

vrrp_script chk_mysql {
    script "/etc/keepalived/check_mysql.sh"
    interval 2
    weight -20
}

vrrp_instance VI_1 {
    state BACKUP          # Chạy ở chế độ dự phòng
    interface ens3
    virtual_router_id 51  # Giống hệt Master
    priority 90           # Thấp hơn Master (100)
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass Secret@123 # Giống hệt Master
    }

    virtual_ipaddress {
        192.168.78.100/24    # IP VIP GIỐNG HỆT MASTER
    }

    track_script {
        chk_mysql
    }
}
```

Khởi động lại Keepalived:
```bash
sudo systemctl restart keepalived
sudo systemctl enable keepalived
```

---

## PHẦN 4: Kịch bản Kiểm tra (Test Failover)

Để đảm bảo hệ thống tự động nhảy IP đúng như thiết kế, bạn hãy thực hiện các bài test sau:

**Bài Test 1: Giả lập MariaDB trên Master bị chết**
1. Đứng ở **Master**, tắt MariaDB:
   ```bash
   sudo systemctl stop mariadb
   ```
2. Ngay lập tức, check IP trên **Master**:
   ```bash
   ip a show ens3
   ```
   *(Bạn sẽ thấy IP VIP `192.168.78.100` đã biến mất khỏi Master).*
3. Sang **Slave** kiểm tra:
   ```bash
   ip a show ens3
   ```
   *(Bạn sẽ thấy IP VIP `192.168.78.100` đã xuất hiện trên Slave. Ứng dụng của bạn tiếp tục chạy bình thường vào con Slave).*

**Bài Test 2: Master phục hồi**
1. Đứng ở **Master**, bật lại MariaDB:
   ```bash
   sudo systemctl start mariadb
   ```
2. Vì Master có Priority (100) cao hơn Slave (90), nên khi nó sống lại, Keepalived sẽ **tự động giật lại IP VIP** mang về Master. 
3. Kiểm tra lại `ip a` trên 2 máy để xác nhận VIP đã về lại đúng nhà (Master).