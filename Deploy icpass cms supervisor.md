# Hướng dẫn triển khai IcpassCMS lên VM bằng Supervisor

| Thông tin | Giá trị |
|---|---|
| Ứng dụng | `ICPassCMS.jar` (Spring Boot 3.4.1, main class `GameasyMobifoneCmsApplication`) |
| Yêu cầu | Java 17+, Supervisor, MySQL (`172.16.1.203:3306`), Redis (localhost) |
| VM | `59.153.245.168`, SSH port `2223`, user `quannm` |
| Thư mục chạy | `/opt/icpass_cms/runner/` |
| Thư mục log | `/var/log/icpass_cms/` |
| Port | `8080` (YAML không đặt `server.port` → mặc định) |
| Phụ thuộc | Gọi health-check tới IcpassCCSP tại `http://localhost:8888/ping` |

---

## 1. Sửa `application.yaml` trước khi đẩy lên

File YAML hiện có giá trị dành cho máy Windows, cần sửa trước:

### 1.1. Bắt buộc: đường dẫn log folder

```yaml
app:
  log:
    folder: C:\MyData\ftp        # ← đường dẫn Windows, sẽ lỗi trên Linux
```

Đổi thành:

```yaml
app:
  log:
    folder: /opt/icpass_cms/runner/ftp
```

### 1.2. Nên thêm: port cố định và tắt show-sql

Thêm vào cuối file (hoặc đầu file, ngang cấp với `spring:`):

```yaml
server:
  port: 8080
```

Trong `spring.jpa`, đổi `show-sql: true` → `show-sql: false` để log không bị tràn SQL khi chạy production.

### 1.3. Kiểm tra lại

- `spring.datasource.url`: `jdbc:mysql://172.16.1.203:3306/gameasy_mobifone` — VM phải route được tới IP nội bộ `172.16.1.203`. Nếu MySQL nằm ngay trên VM thì đổi thành `localhost`.
- `service.health.url`: `http://localhost:8888/ping` — IcpassCCSP phải chạy cùng VM, đúng port 8888.
- File chứa password MySQL và Telegram bot token → sau khi copy lên phải `chmod 600`.

---

## 2. Tạo thư mục trên VM (chạy từ PowerShell Windows)

```powershell
ssh -t -p 2223 quannm@59.153.245.168 "sudo mkdir -p /opt/icpass_cms/runner/ftp /var/log/icpass_cms && sudo chown -R quannm /opt/icpass_cms"
```

---

## 3. Đẩy file lên VM

```powershell
cd "C:\Users\quannm\Downloads\Telegram Desktop"
scp -P 2223 ICPassCMS.jar application.yaml quannm@59.153.245.168:/opt/icpass_cms/runner/
```

Jar nặng ~103 MB, chờ copy xong. Nếu mạng chập chờn, dùng WinSCP (SFTP, port 2223).

---

## 4. SSH vào VM

```powershell
ssh -p 2223 quannm@59.153.245.168
```

Các bước sau chạy **trên VM**.

---

## 5. Kiểm tra môi trường

```bash
java -version                       # >= 17 (đã cài ở bước IcpassCCSP)
which supervisorctl
ls -la /opt/icpass_cms/runner/
chmod 600 /opt/icpass_cms/runner/application.yaml
```

Kiểm tra kết nối tới các dịch vụ phụ thuộc:

```bash
ss -lntp | grep -E "6379|8080|8888"             # Redis chạy, 8888 (CCSP) chạy, 8080 trống
nc -zv 172.16.1.203 3306 || timeout 3 bash -c '</dev/tcp/172.16.1.203/3306' && echo "MySQL OK"
curl -s http://localhost:8888/ping               # CCSP đã lên chưa
```

---

## 6. Tạo cấu hình Supervisor

### Ubuntu / Debian

```bash
sudo tee /etc/supervisor/conf.d/icpass_cms.conf > /dev/null <<'EOF'
[program:IcpassCMS]
command=/usr/bin/java -Xms512m -Xmx1g -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Saigon -jar ICPassCMS.jar --spring.config.location=file:./application.yaml
directory=/opt/icpass_cms/runner/
user=root
autostart=true
autorestart=true
startsecs=15
stopwaitsecs=30
stopasgroup=true
killasgroup=true
stopsignal=TERM
stderr_logfile=/var/log/icpass_cms/cms.err.log
stdout_logfile=/var/log/icpass_cms/cms.out.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=5
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=5
EOF
```

### RHEL / CentOS

Nội dung giống hệt, ghi vào `/etc/supervisord.d/icpass_cms.ini`.

### Lưu ý về `--spring.config.location`

Trong jar có sẵn `application.yaml` với `spring.profiles.active: local`, cùng `application-local.yaml` (trỏ tới DB `172.16.20.232`) và `application-203.yaml`. Dùng `--spring.config.location` sẽ **bỏ qua hoàn toàn** các file này → chỉ dùng YAML bên ngoài, không kích hoạt profile `local`. Đây là hành vi mong muốn; không cần thêm `--spring.profiles.active`.

---

## 7. Khởi động

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl status
```

Kết quả mong đợi:

```
IcpassCCSP    RUNNING   pid 1234, uptime 0:30:00
IcpassCMS     RUNNING   pid 5678, uptime 0:00:20
```

---

## 8. Kiểm tra hoạt động

```bash
tail -f /var/log/icpass_cms/cms.out.log
```

Đợi dòng `Started GameasyMobifoneCmsApplication in ... seconds`, nhấn `Ctrl+C`, rồi:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/
```

Log nghiệp vụ: `/opt/icpass_cms/runner/log/full.log`.

---

## 9. Lệnh quản lý

```bash
sudo supervisorctl status IcpassCMS
sudo supervisorctl restart IcpassCMS
sudo supervisorctl stop IcpassCMS
sudo supervisorctl start IcpassCMS
sudo supervisorctl tail -f IcpassCMS
```

Quản lý cả 2 service cùng lúc:

```bash
sudo supervisorctl restart IcpassCCSP IcpassCMS
sudo supervisorctl status
```

---

## 10. Cập nhật phiên bản mới

Local:

```powershell
scp -P 2223 ICPassCMS.jar quannm@59.153.245.168:/opt/icpass_cms/runner/ICPassCMS.jar.new
```

VM:

```bash
cd /opt/icpass_cms/runner
cp ICPassCMS.jar ICPassCMS.jar.bak_$(date +%Y%m%d_%H%M)
mv ICPassCMS.jar.new ICPassCMS.jar
sudo supervisorctl restart IcpassCMS
sudo supervisorctl status IcpassCMS
```

---

## 11. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `FATAL` / `BACKOFF` | Sai đường dẫn Java, thiếu jar/yaml | `which java`, `ls /opt/icpass_cms/runner/` |
| `Communications link failure` | Không tới được `172.16.1.203:3306` | Kiểm tra route/firewall tới MySQL, hoặc đổi host trong YAML |
| `Access denied for user 'root'` | Sai password MySQL | Sửa `spring.datasource.password` |
| `Unable to connect to Redis` | Redis chưa chạy | `systemctl status redis` |
| `Port 8080 was already in use` | Port bị chiếm | `ss -lntp \| grep 8080`, đổi `server.port` |
| Lỗi liên quan `C:\MyData\ftp` / `NoSuchFileException` | Chưa sửa `app.log.folder` | Sửa theo mục 1.1, restart |
| Telegram không nhận cảnh báo | VM không ra được `api.telegram.org` | `curl -I https://api.telegram.org` để kiểm tra outbound |
| Health-check báo CCSP down | IcpassCCSP chưa chạy hoặc sai port | `supervisorctl status IcpassCCSP` |

Xem lỗi chi tiết:

```bash
tail -n 100 /var/log/icpass_cms/cms.err.log
tail -n 100 /var/log/icpass_cms/cms.out.log
```

---

## 12. Lưu ý vận hành

1. **Thứ tự khởi động**: CMS gọi health-check tới CCSP (`localhost:8888/ping`) theo cron `hourly-scanning: 0 0/1 * * * *` (mỗi phút). Nếu CCSP chưa chạy, CMS vẫn lên được nhưng sẽ báo cảnh báo liên tục qua Telegram. Nên start CCSP trước.
2. **Cron trong app** (`heal-scanning`, `active-scanning`, `hourly-scanning`) chạy theo timezone JVM → tham số `-Duser.timezone=Asia/Saigon` trong `command` đảm bảo đúng giờ VN.
3. `spring.jpa.hibernate.ddl-auto: update` — cả CCSP và CMS cùng trỏ DB `gameasy_mobifone` và cùng `update` schema. Với production nên đổi thành `validate` sau lần chạy đầu để tránh 2 app vô tình sửa schema của nhau.
4. Nếu cần mở CMS ra ngoài: mở firewall port 8080 hoặc đặt Nginx reverse proxy. Không nên expose trực tiếp nếu CMS chưa có xác thực.
5. Hai service dùng chung Redis `localhost:6379` DB 0. Nếu có xung đột key, đặt `spring.data.redis.database` khác nhau cho từng app.