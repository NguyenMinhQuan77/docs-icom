# Hướng dẫn Cài đặt và Quản lý Tiến trình với Supervisor

Supervisor là một hệ thống client/server cho phép người dùng giám sát và kiểm soát một số lượng lớn các tiến trình (processes) trên hệ điều hành UNIX-like. Công cụ này rất hữu ích để chạy các background worker, queue listener (như Laravel Horizon, Celery), hoặc các ứng dụng web (Node.js, Python, Go).

---

## 1. Cài đặt Supervisor

Tài liệu này hướng dẫn cài đặt trên môi trường **Ubuntu/Debian**.

Cập nhật danh sách gói phần mềm và cài đặt Supervisor thông qua `apt`:

```bash
sudo apt update
sudo apt install supervisor -y
```

Sau khi cài đặt thành công, service của Supervisor sẽ tự động được khởi động. Bạn có thể kiểm tra trạng thái bằng lệnh:

```bash
sudo systemctl status supervisor
```

---

## 2. Cấu trúc Thư mục và File Cấu hình

*   **File cấu hình chính:** `/etc/supervisor/supervisord.conf` (Thường không cần chỉnh sửa file này).
*   **Thư mục chứa cấu hình các ứng dụng (programs):** `/etc/supervisor/conf.d/`
    *   Mỗi ứng dụng hoặc worker nên có một file cấu hình riêng với đuôi `.conf` đặt trong thư mục này.

---

## 3. Tạo Cấu hình cho một Ứng dụng mẫu

Giả sử bạn có một ứng dụng web hoặc một worker cần chạy ngầm liên tục. Chúng ta sẽ tạo một file cấu hình cho nó.

**Bước 1:** Tạo một file `.conf` mới trong thư mục cấu hình:

```bash
sudo nano /etc/supervisor/conf.d/my_app_worker.conf
```

**Bước 2:** Thêm nội dung cấu hình mẫu sau:

```ini
[program:my_app_worker]
# Lệnh để chạy ứng dụng của bạn
command=/usr/bin/php /var/www/my_app/artisan queue:work --sleep=3 --tries=3

# Thư mục gốc nơi lệnh sẽ được thực thi
directory=/var/www/my_app

# Chạy tiến trình này tự động khi Supervisor khởi động
autostart=true

# Tự động khởi động lại tiến trình nếu nó bị crash
autorestart=true

# Chạy tiến trình dưới quyền của user cụ thể (khuyến cáo không dùng root nếu không cần thiết)
user=www-data

# Số lượng tiến trình (process) chạy song song (nếu cần chạy nhiều worker cùng lúc)
numprocs=1

# Tên của các process con (hữu ích khi numprocs > 1)
process_name=%(program_name)s_%(process_num)02d

# Chuyển hướng log lỗi (stderr) vào chung với log tiêu chuẩn (stdout)
redirect_stderr=true

# Đường dẫn lưu file log của ứng dụng
stdout_logfile=/var/log/supervisor/my_app_worker.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
```

*Lưu ý: Thay đổi `command`, `directory`, và `user` cho phù hợp với dự án thực tế của bạn.*

---

## 4. Cập nhật và Quản lý Supervisor

Mỗi khi bạn tạo mới hoặc thay đổi một file cấu hình trong thư mục `conf.d`, bạn cần thông báo cho Supervisor biết để cập nhật lại.

**Đọc lại các file cấu hình mới:**
```bash
sudo supervisorctl reread
```

**Áp dụng các thay đổi và khởi động tiến trình mới:**
```bash
sudo supervisorctl update
```

**Các lệnh quản lý tiến trình thường dùng:**

*   Kiểm tra trạng thái của tất cả các tiến trình:
    ```bash
    sudo supervisorctl status
    ```
*   Khởi động một tiến trình:
    ```bash
    sudo supervisorctl start my_app_worker:*
    ```
*   Dừng một tiến trình:
    ```bash
    sudo supervisorctl stop my_app_worker:*
    ```
*   Khởi động lại một tiến trình:
    ```bash
    sudo supervisorctl restart my_app_worker:*
    ```
*   Khởi động lại toàn bộ Supervisor (chỉ dùng khi cần thiết):
    ```bash
    sudo service supervisor restart
    ```

---

## 5. (Tùy chọn) Bật Giao diện Web Quản lý

Supervisor cung cấp một giao diện web tích hợp sẵn giúp bạn theo dõi và thao tác start/stop các tiến trình trực quan qua trình duyệt.

**Bước 1:** Mở file cấu hình chính:
```bash
sudo nano /etc/supervisor/supervisord.conf
```

**Bước 2:** Thêm hoặc mở khóa (uncomment) đoạn cấu hình `[inet_http_server]` sau:

```ini
[inet_http_server]
port=*:9001              ; Lắng nghe trên cổng 9001 ở tất cả các IP
username=admin           ; Tên đăng nhập
password=super_secret    ; Mật khẩu bảo mật
```

**Bước 3:** Khởi động lại service Supervisor:
```bash
sudo systemctl restart supervisor
```

Bây giờ bạn có thể mở trình duyệt và truy cập vào `http://<IP-SERVER>:9001` (Nhớ đảm bảo tường lửa đã mở cổng 9001) để quản lý các tiến trình qua giao diện đồ họa.