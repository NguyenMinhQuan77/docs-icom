# Tài liệu Triển khai MariaDB Master-Slave Replication

**Thông tin Môi trường Triển khai**
* **Hệ điều hành:** Ubuntu 22.04.1 LTS (Jammy Jellyfish)
* **Master Node:** 192.168.78.71
* **Slave Node:** 192.168.78.223
* **Cấp quyền:** Yêu cầu quyền `root` hoặc `sudo` trên cả hai máy chủ.

---

## PHẦN 1: Cài đặt và Chuẩn bị (Thực hiện trên CẢ Master và Slave)

**1. Cập nhật hệ thống và cài đặt MariaDB**
```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install mariadb-server mariadb-client -y
```

**2. Khởi động và thiết lập chạy cùng hệ thống**
```bash
sudo systemctl start mariadb
sudo systemctl enable mariadb
```

**3. Bảo mật cơ sở dữ liệu bước đầu**
Chạy lệnh bảo mật mặc định của MariaDB và làm theo hướng dẫn (Thiết lập mật khẩu root, xoá anonymous users, disallow root login remotely, remove test database):
```bash
sudo mysql_secure_installation
```

**4. Cấu hình Tường lửa (UFW)**
Chỉ cho phép các máy chủ trong dải mạng nội bộ hoặc cấu hình mở port 3306 cho nhau:
*   **Trên Master:** `sudo ufw allow from 192.168.78.223 to any port 3306`
*   **Trên Slave:** `sudo ufw allow from 192.168.78.71 to any port 3306`

---

## PHẦN 2: Cấu hình Master Node (IP: 192.168.78.71)

**1. Chỉnh sửa file cấu hình MariaDB**
Mở file cấu hình chính của MariaDB:
```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
Tìm các dòng sau và chỉnh sửa/thêm vào mục `[mysqld]`:
```ini
bind-address            = 192.168.78.71
server-id               = 1
log_bin                 = /var/log/mysql/mysql-bin.log
# binlog_do_db          = ten_db_can_dong_bo # (Tuỳ chọn: Nếu chỉ muốn đồng bộ 1 DB cụ thể, bỏ comment dòng này)
```

**2. Khởi động lại dịch vụ MariaDB**
```bash
sudo systemctl restart mariadb
```

**3. Tạo User cấp quyền Replication**
Truy cập vào MariaDB console:
```bash
sudo mysql -u root -p
```
Thực thi các lệnh SQL sau để tạo user và cấp quyền (thay thế `P@ssw0rdReplication` bằng mật khẩu đủ mạnh theo tiêu chuẩn công ty):
```sql
CREATE USER 'repl_user'@'192.168.78.223' IDENTIFIED BY 'P@ssw0rdReplication';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'192.168.78.223';
FLUSH PRIVILEGES;
```

**4. Lấy thông tin Trạng thái Master (Rất quan trọng)**
Thực thi lệnh sau và **ghi lại kết quả** (Đặc biệt là cột `File` và `Position`):
```sql
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
```
*Ví dụ Output:*
| File | Position | Binlog_Do_DB | Binlog_Ignore_DB |
| :--- | :--- | :--- | :--- |
| **mysql-bin.000001** | **328** | | |

*Lưu ý: Không tắt console MariaDB này cho đến khi bạn đã cấu hình xong Slave, để giữ Lock (tránh việc dữ liệu mới được ghi vào trong quá trình đồng bộ ban đầu). Nếu dữ liệu Master trống (server mới hoàn toàn), bạn có thể gõ `UNLOCK TABLES;` luôn.*

---

## PHẦN 3: Cấu hình Slave Node (IP: 192.168.78.223)

**1. Chỉnh sửa file cấu hình MariaDB**
Mở file cấu hình:
```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```
Tìm và cấu hình các thông số sau trong block `[mysqld]`:
```ini
bind-address            = 192.168.78.223
server-id               = 2
relay-log               = /var/log/mysql/mysql-relay-bin.log
read_only               = 1
```

**2. Khởi động lại dịch vụ MariaDB**
```bash
sudo systemctl restart mariadb
```

**3. Kết nối Slave với Master**
Truy cập vào MariaDB console trên Slave:
```bash
sudo mysql -u root -p
```
Thực thi lệnh sau (thay thế `MASTER_LOG_FILE` và `MASTER_LOG_POS` bằng giá trị chính xác bạn đã lấy được ở **Phần 2 - Bước 4**):
```sql
STOP SLAVE;

CHANGE MASTER TO
  MASTER_HOST='192.168.78.71',
  MASTER_USER='repl_user',
  MASTER_PASSWORD='P@ssw0rdReplication',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=328;

START SLAVE;
```

**4. Kiểm tra Trạng thái Replication**
```sql
SHOW SLAVE STATUS\G;
```
Hãy chú ý hai dòng sau, nếu cả hai đều báo **Yes** nghĩa là quá trình thiết lập đã thành công:
*   `Slave_IO_Running: Yes`
*   `Slave_SQL_Running: Yes`

---

## PHẦN 4: Hoàn thiện & Khắc phục sự cố

**1. Mở khoá bảng trên Master**
Quay lại console MariaDB trên **Master Node (192.168.78.71)** và gõ lệnh để giải phóng lock:
```sql
UNLOCK TABLES;
```

**2. Kiểm tra thực tế**
*   Trên **Master**: Tạo một database hoặc table thử nghiệm.
    ```sql
    CREATE DATABASE rep_test;
    ```
*   Trên **Slave**: Kiểm tra xem database đã được đồng bộ sang chưa.
    ```sql
    SHOW DATABASES;
    ```

**3. Xử lý lỗi phổ biến (Nếu có)**
Nếu `Slave_IO_Running` hoặc `Slave_SQL_Running` báo **No**:
*   Kiểm tra lại Firewall có chặn port 3306 giữa 2 IP không.
*   Kiểm tra lại User, Password, IP cấp quyền ở bước tạo user replication.
*   Kiểm tra xem `MASTER_LOG_FILE` và `MASTER_LOG_POS` nhập trên Slave có khớp tuyệt đối với thông tin từ Master không. Đọc chi tiết lỗi tại mục `Last_IO_Error` và `Last_SQL_Error` khi chạy lệnh `SHOW SLAVE STATUS\G;`.