# Hướng dẫn triển khai IcpassCCSP API lên VM bằng Supervisor

| Thông tin | Giá trị |
|---|---|
| Ứng dụng | `icpass_ccsp.jar` (Spring Boot 3.3.4, main class `GameasyMobifoneApplication`) |
| Yêu cầu | Java 17+, Supervisor, MySQL, Redis |
| VM | `59.153.245.168`, SSH port `2223`, user `quannm` |
| Thư mục chạy | `/opt/icpass_ccsp/runner/` |
| Thư mục log | `/var/log/icpass_ccsp/` |
| Port API | `8888` (theo `server.port` trong `application.properties`) |

---

## 1. Chuẩn bị trên máy local (Windows)

Mở **PowerShell**, chuyển vào thư mục chứa file:

```powershell
cd "C:\Users\quannm\Downloads\Telegram Desktop"
```

Cần có 2 file:

- `icpass_ccsp.jar`
- `application.properties`

> Nếu trong thư mục có thêm `application.yml`, chỉ dùng **một** trong hai. Spring chỉ nạp file được chỉ ở `--spring.config.location`.

---

## 2. Tạo thư mục trên VM

```powershell
ssh -t -p 2223 quannm@59.153.245.168 "sudo mkdir -p /opt/icpass_ccsp/runner /var/log/icpass_ccsp && sudo chown -R quannm /opt/icpass_ccsp"
```

- `-t` để ssh cấp terminal cho `sudo` hỏi password.
- Sẽ hỏi password SSH, sau đó hỏi password sudo.

---

## 3. Đẩy file lên VM

```powershell
scp -P 2223 icpass_ccsp.jar application.properties quannm@59.153.245.168:/opt/icpass_ccsp/runner/
```

> `scp` dùng **`-P` viết hoa** cho port (khác với `ssh -p`).
> Nếu mạng chậm/không ổn định, có thể dùng WinSCP (SFTP, host `59.153.245.168`, port `2223`).

---

## 4. SSH vào VM

```powershell
ssh -p 2223 quannm@59.153.245.168
```

Các bước từ đây trở đi chạy **trên VM**.

---

## 5. Kiểm tra & cài đặt phụ thuộc

```bash
cat /etc/os-release        # xem OS
java -version              # cần >= 17
which supervisorctl        # kiểm tra Supervisor
```

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y openjdk-17-jre-headless supervisor
sudo systemctl enable --now supervisor
```

### RHEL / CentOS / Rocky / AlmaLinux

```bash
sudo dnf install -y java-17-openjdk-headless supervisor
sudo systemctl enable --now supervisord
```

Kiểm tra đường dẫn Java thực tế (dùng cho `command` bên dưới):

```bash
which java    # thường là /usr/bin/java
```

---

## 6. Kiểm tra file & phân quyền

```bash
ls -la /opt/icpass_ccsp/runner/
chmod 600 /opt/icpass_ccsp/runner/application.properties   # file chứa password DB/FTP
```

Kiểm tra MySQL, Redis và port 8888:

```bash
ss -lntp | grep -E "3306|6379|8888"
```

- `3306` và `6379` phải đang lắng nghe.
- `8888` **không** được bị chiếm.

---

## 7. Tạo cấu hình Supervisor

### Ubuntu / Debian

```bash
sudo tee /etc/supervisor/conf.d/icpass_ccsp.conf > /dev/null <<'EOF'
[program:IcpassCCSP]
command=/usr/bin/java -Xms512m -Xmx1g -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Saigon -jar icpass_ccsp.jar --spring.config.location=file:./application.properties
directory=/opt/icpass_ccsp/runner/
user=root
autostart=true
autorestart=true
startsecs=10
stopwaitsecs=35
stopasgroup=true
killasgroup=true
stopsignal=TERM
stderr_logfile=/var/log/icpass_ccsp/api.err.log
stdout_logfile=/var/log/icpass_ccsp/api.out.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=5
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=5
EOF
```

### RHEL / CentOS

Nội dung giống hệt, chỉ đổi đường dẫn file:

```bash
sudo tee /etc/supervisord.d/icpass_ccsp.ini > /dev/null <<'EOF'
... (nội dung như trên) ...
EOF
```

### Giải thích các tham số quan trọng

| Tham số | Lý do |
|---|---|
| `stopsignal=TERM` | Spring Boot chỉ graceful shutdown với SIGTERM. SIGQUIT chỉ in thread dump, không tắt app → Supervisor sẽ phải `kill -9`. |
| `stopwaitsecs=35` | Properties có `spring.task.scheduling.shutdown.await-termination-period=30s`, cần chờ lâu hơn 30s. |
| `stopasgroup` / `killasgroup` | Đảm bảo tắt toàn bộ tiến trình con của JVM. |
| `file:./application.properties` | Đường dẫn tương đối theo `directory`, prefix `file:` để Spring Boot 3 hiểu rõ. |
| `-Xmx1g` | Giới hạn heap; chỉnh theo RAM của VM. |
| `*_maxbytes` / `*_backups` | Xoay vòng log, tránh đầy `/var/log`. |

---

## 8. Khởi động dịch vụ

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl status IcpassCCSP
```

Kết quả mong đợi:

```
IcpassCCSP    RUNNING   pid 12345, uptime 0:00:15
```

---

## 9. Kiểm tra hoạt động

```bash
tail -f /var/log/icpass_ccsp/api.out.log
```

Đợi dòng `Started GameasyMobifoneApplication in ... seconds`, nhấn `Ctrl+C`, rồi:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8888/
```

Log nghiệp vụ của app nằm tại `/opt/icpass_ccsp/runner/log/full.log` (theo `logging.file.name=./log/full.log`).

---

## 10. Lệnh quản lý hằng ngày

```bash
sudo supervisorctl status IcpassCCSP     # trạng thái
sudo supervisorctl restart IcpassCCSP    # khởi động lại
sudo supervisorctl stop IcpassCCSP       # dừng
sudo supervisorctl start IcpassCCSP      # chạy
sudo supervisorctl tail -f IcpassCCSP    # xem stdout trực tiếp
```

---

## 11. Cập nhật phiên bản mới

Trên local:

```powershell
scp -P 2223 icpass_ccsp.jar quannm@59.153.245.168:/opt/icpass_ccsp/runner/icpass_ccsp.jar.new
```

Trên VM:

```bash
cd /opt/icpass_ccsp/runner
cp icpass_ccsp.jar icpass_ccsp.jar.bak_$(date +%Y%m%d_%H%M)   # backup
mv icpass_ccsp.jar.new icpass_ccsp.jar
sudo supervisorctl restart IcpassCCSP
sudo supervisorctl status IcpassCCSP
```

Rollback nếu lỗi: copy file `.bak_*` ngược lại rồi `restart`.

---

## 12. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `FATAL` / `BACKOFF` ngay khi start | Sai đường dẫn Java, thiếu file jar/properties | `which java`, `ls /opt/icpass_ccsp/runner/` |
| Log có `Communications link failure` | MySQL chưa chạy hoặc sai host/port | `ss -lntp \| grep 3306`, kiểm tra `spring.datasource.url` |
| Log có `Access denied for user` | Sai user/password MySQL | Sửa `spring.datasource.username/password` |
| Log có `Unable to connect to Redis` | Redis chưa chạy | `systemctl status redis` |
| `Port 8888 was already in use` | Port bị chiếm | `ss -lntp \| grep 8888`, đổi `server.port` |
| `UnsupportedClassVersionError` | Java < 17 | Cài Java 17 |
| App chạy nhưng tắt chậm / bị kill | `stopwaitsecs` quá nhỏ | Tăng `stopwaitsecs` |

Xem lỗi chi tiết:

```bash
tail -n 100 /var/log/icpass_ccsp/api.err.log
tail -n 100 /var/log/icpass_ccsp/api.out.log
```

---

## 13. Lưu ý về cấu hình

1. **Config trong jar bị thay thế hoàn toàn.** Bên trong jar có sẵn `application.properties` với `spring.profiles.active=203` và `spring.redis.database=15`, cùng `application-203.properties`. Khi dùng `--spring.config.location`, Spring **không nạp** các file này nữa → profile `203` không kích hoạt, Redis dùng DB `0`.
   - Nếu VM chạy chung Redis với app khác, thêm vào `application.properties` ngoài: `spring.redis.database=15`.
   - Nếu muốn giữ profile `203` trong jar, đổi `--spring.config.location` thành `--spring.config.additional-location=file:./application.properties` và thêm `--spring.profiles.active=203`.
2. `spring.jpa.hibernate.ddl-auto=update` tự sửa schema khi khởi động. Với production nên đổi thành `validate` sau lần chạy đầu.
3. Các thư mục `./log` và `./cdr` được tạo tương đối theo `directory`, tức `/opt/icpass_ccsp/runner/`. Nếu đổi `user` trong Supervisor khác `root`, phải `chown` thư mục này cho user đó.
4. Nếu cần mở API ra ngoài, mở firewall cho port 8888 (hoặc đặt Nginx reverse proxy phía trước):
   ```bash
   sudo ufw allow 8888/tcp          # Ubuntu
   sudo firewall-cmd --permanent --add-port=8888/tcp && sudo firewall-cmd --reload   # RHEL
   ```