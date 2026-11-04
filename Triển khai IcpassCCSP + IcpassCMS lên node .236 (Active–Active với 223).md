# Triển khai IcpassCCSP + IcpassCMS lên node .236 (Active–Active với 223)

## 0. Tổng quan kiến trúc

| | Node 1 (đã chạy) | Node 2 (triển khai mới) |
|---|---|---|
| Hostname | `MariaDB-Master-223` | `MariaDB-Slave-71` |
| IP public | `59.153.245.168` | `59.153.245.236` |
| IP private | `192.168.78.223` | `192.168.78.71` |
| MariaDB | **Master** (ghi) | Slave (chỉ đọc) |
| Redis 6379 | **Master** (ghi) | Replica (chỉ đọc) |
| IcpassCCSP | port 8888 | port 8888 |
| IcpassCMS | port 8080 | port 8080 |

**Nguyên tắc bắt buộc:** cả 2 API trên **cả 2 node** đều phải kết nối tới **MariaDB master** và **Redis master** ở `192.168.78.223`. MariaDB slave và Redis replica trên .71 là read-only — app ghi vào sẽ lỗi `READONLY` / `--read-only`.

```
          ┌────────── LB / DNS round-robin (tuỳ chọn) ──────────┐
          │                                                      │
   ┌──────▼──────┐                                       ┌───────▼─────┐
   │  Node 223   │                                       │  Node 236   │
   │ CCSP :8888  │──┐                                 ┌──│ CCSP :8888  │
   │ CMS  :8080  │  │                                 │  │ CMS  :8080  │
   └─────────────┘  │                                 │  └─────────────┘
                    ▼                                 ▼
          ┌──────────────────────────────────────────────────┐
          │ 192.168.78.223 : MariaDB master 3306 + Redis 6379 │
          └───────────────────────┬──────────────────────────┘
                                  │ replication
                        ┌─────────▼─────────┐
                        │ 192.168.78.71      │
                        │ MariaDB slave      │
                        │ Redis replica      │
                        └────────────────────┘
```

### Giới hạn active–active cần biết trước

1. **Job/cron chạy trùng**: CCSP có cron tải CDR, gửi notify; CMS có cron scan + cảnh báo Telegram. Hai node cùng chạy → chạy 2 lần. Tài liệu này **tắt cron trên node 2**, node 2 chỉ phục vụ HTTP + xử lý hàng đợi Redis.
2. **Hàng đợi Redis dùng chung an toàn**: `LPOP/RPOP` là atomic, 2 instance CCSP cùng lấy từ một queue không xử lý trùng.
3. **Không tự failover**: app CCSP không hỗ trợ Sentinel/password (RedisConfig chỉ nhận host/port tĩnh). Nếu 223 chết, phải đổi tay config cả 2 node sang master mới. Xem mục 11.

---

## 1. Chuẩn bị trên node 223 (MariaDB master)

Cấp quyền DB cho user app từ IP .71:

```bash
sudo mysql -u root
```

```sql
CREATE USER IF NOT EXISTS 'gameasy'@'192.168.78.71' IDENTIFIED BY 'Gameasy@2026';
GRANT ALL PRIVILEGES ON `icpass-mbf-api`.* TO 'gameasy'@'192.168.78.71';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'gameasy'@'192.168.78.71';
EXIT;
```

Firewall trên 223 — cho .71 vào MariaDB và Redis (6379 đã mở cho .71 ở bước trước, kiểm tra lại):

```bash
sudo ufw allow from 192.168.78.71 to any port 3306 proto tcp comment 'icpass node2 -> mariadb'
sudo ufw allow from 192.168.78.71 to any port 6379 proto tcp comment 'icpass node2 -> redis'
sudo ufw status numbered | grep -E "3306|6379"
```

MariaDB trên 223 đang bind `192.168.78.223` (đã kiểm tra `ss -lntp`), Redis bind `127.0.0.1 192.168.78.223` → .71 kết nối được qua IP private.

---

## 2. Từ Windows: đẩy file lên node 236

```powershell
cd "C:\Users\quannm\Downloads\Telegram Desktop"

ssh -t -p 2223 quannm@59.153.245.236 "sudo mkdir -p /opt/icpass_ccsp/runner /opt/icpass_cms/runner/ftp /var/log/icpass_ccsp /var/log/icpass_cms && sudo chown -R quannm /opt/icpass_ccsp /opt/icpass_cms"

scp -P 2223 icpass_ccsp.jar application.properties quannm@59.153.245.236:/opt/icpass_ccsp/runner/
scp -P 2223 ICPassCMS.jar application.yaml      quannm@59.153.245.236:/opt/icpass_cms/runner/
```

> Nếu SSH node 236 dùng port khác 2223 thì đổi `-p`/`-P` cho đúng.

Cách nhanh hơn — copy thẳng từ 223 sang 236 (file đã chỉnh đúng trên 223), chạy **trên 223**:

```bash
scp /opt/icpass_ccsp/runner/{icpass_ccsp.jar,application.properties} quannm@192.168.78.71:/opt/icpass_ccsp/runner/
scp /opt/icpass_cms/runner/{ICPassCMS.jar,application.yaml}          quannm@192.168.78.71:/opt/icpass_cms/runner/
```

---

## 3. SSH vào node 236

```powershell
ssh -p 2223 quannm@59.153.245.236
```

Các bước sau chạy **trên node 236**.

---

## 4. Cài Java 17 & Supervisor

```bash
cat /etc/os-release | head -2
java -version 2>&1 | head -1
which supervisorctl
```

Nếu thiếu (Ubuntu 22.04):

```bash
sudo apt update
sudo apt install -y openjdk-17-jre-headless supervisor
sudo systemctl enable --now supervisor
```

---

## 5. Kiểm tra kết nối tới master 223

```bash
# MariaDB master
mysql -h 192.168.78.223 -u gameasy -p'Gameasy@2026' -e 'SELECT 1; SHOW DATABASES;'

# Redis master (không password)
redis-cli -h 192.168.78.223 -p 6379 ping          # PONG
redis-cli -h 192.168.78.223 -p 6379 info replication | grep -E "^role|connected_slaves"   # role:master

# Redis local trên .71 phải là replica và đang up
redis-cli info replication | grep -E "^role|master_link_status"   # role:slave, up

# Port app còn trống
ss -lntp | grep -E ":8888|:8080"
```

Nếu `redis-cli` chưa có: `sudo apt install -y redis-tools`.

---

## 6. Cấu hình IcpassCCSP (`/opt/icpass_ccsp/runner/application.properties`)

Mở `vi /opt/icpass_ccsp/runner/application.properties` và đảm bảo các dòng sau:

```properties
# --- Database: trỏ MASTER 223, không dùng localhost ---
spring.datasource.driverClassName=com.mysql.cj.jdbc.Driver
spring.datasource.url=jdbc:mysql://192.168.78.223:3306/icpass-mbf-api?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Saigon
spring.datasource.username=gameasy
spring.datasource.password=Gameasy@2026
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MariaDBDialect
spring.jpa.hibernate.ddl-auto=update

# --- Redis: trỏ MASTER 223 (RedisConfig trong jar KHÔNG đọc password) ---
spring.redis.host=192.168.78.223
spring.redis.port=6379
spring.redis.password=

server.port=8888

# --- Tắt job trùng trên node 2 (node 223 giữ nguyên) ---
cdr.cron.enable=false
is.send_notify=0
```

Khoá quyền file:

```bash
chmod 600 /opt/icpass_ccsp/runner/application.properties
grep -E "^(spring\.(datasource|redis\.host|redis\.port)|server\.port|cdr\.cron\.enable|is\.send_notify)" /opt/icpass_ccsp/runner/application.properties
```

> **Tuyệt đối không** để `ddl-auto=create` — sẽ xoá toàn bộ bảng mỗi lần restart.

---

## 7. Cấu hình IcpassCMS (`/opt/icpass_cms/runner/application.yaml`)

Mở `vi /opt/icpass_cms/runner/application.yaml`, sửa các khối sau:

```yaml
spring:
  datasource:
    url: jdbc:mysql://192.168.78.223:3306/icpass-mbf-api?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Saigon
    username: gameasy
    password: Gameasy@2026
    hikari:
      jdbc-url: jdbc:mysql://192.168.78.223:3306/icpass-mbf-api?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Saigon
  jpa:
    database-platform: org.hibernate.dialect.MariaDBDialect
    hibernate:
      ddl-auto: update
    show-sql: false
  data:
    redis:
      host: 192.168.78.223      # master, không dùng localhost
      port: 6379
      # không có password

server:
  port: 8080

app:
  # Tắt cron trên node 2 — "-" là giá trị Spring dùng để disable @Scheduled(cron)
  heal-scanning: "-"
  active-scanning: "-"
  hourly-scanning: "-"
  enable-get-all: true
  log:
    folder: /opt/icpass_cms/runner/ftp     # KHÔNG để đường dẫn Windows

service:
  health:
    url: http://localhost:8888/ping         # CCSP cùng node
```

> Nếu app báo lỗi parse cron với `"-"` (code không dùng `@Scheduled(cron=...)` chuẩn), thay bằng lịch không bao giờ tới: `"0 0 0 31 2 *"` (31/2).

```bash
chmod 600 /opt/icpass_cms/runner/application.yaml
mkdir -p /opt/icpass_cms/runner/ftp
grep -nE "jdbc:|username|password|host:|port:|scanning|folder" /opt/icpass_cms/runner/application.yaml
```

---

## 8. Cấu hình Supervisor

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

---

## 9. Khởi động & kiểm tra

```bash
sudo supervisorctl reread
sudo supervisorctl update
sleep 30
sudo supervisorctl status
```

Mong đợi:

```
IcpassCCSP    RUNNING   pid ...
IcpassCMS     RUNNING   pid ...
```

Kiểm tra log không còn lỗi kết nối:

```bash
grep -cE "Unable to connect to Redis|Communications link failure|READONLY" /var/log/icpass_ccsp/api.out.log
grep -E "Started GameasyMobifoneApplication|Tomcat started" /var/log/icpass_ccsp/api.out.log | tail -2
grep -E "Started GameasyMobifoneCmsApplication|Tomcat started" /var/log/icpass_cms/cms.out.log | tail -2
curl -s -o /dev/null -w "CCSP %{http_code}\n" http://127.0.0.1:8888/
curl -s -o /dev/null -w "CMS  %{http_code}\n" http://127.0.0.1:8080/
```

Xác nhận app đang nói chuyện với Redis **master** (chạy trên 223):

```bash
redis-cli -p 6379 client list | grep -c "addr=192.168.78.71"     # > 0: node 2 đã kết nối vào master
```

---

## 10. Firewall trên node 236

```bash
sudo ufw status numbered
# mở port API nếu cần truy cập từ ngoài / từ LB
sudo ufw allow 8888/tcp comment 'IcpassCCSP'
sudo ufw allow 8080/tcp comment 'IcpassCMS'
# Redis replica trên .71 chỉ nên nhận từ 223 và localhost
sudo ufw allow from 192.168.78.223 to any port 6379 proto tcp
```

Redis replica trên .71 cũng không có password → kiểm tra `grep -E "^bind" /etc/redis/redis.conf` là `127.0.0.1 192.168.78.71`, không phải `0.0.0.0`.

---

## 11. Vận hành

### Lệnh hằng ngày (mỗi node)

```bash
sudo supervisorctl status
sudo supervisorctl restart IcpassCCSP IcpassCMS
sudo supervisorctl tail -f IcpassCCSP
```

### Rolling update không downtime

1. Update node 236 trước: copy jar `.new` → backup → `mv` → `supervisorctl restart` → kiểm tra log.
2. OK thì làm tương tự node 223.
3. LB (nếu có) tự chuyển traffic; nếu dùng DNS round-robin thì chấp nhận vài request lỗi trong lúc restart.

### Khi node 223 (master) chết — failover thủ công

1. Trên .71 promote Redis: `redis-cli replicaof no one`
2. Promote MariaDB slave: `mysql -e "STOP SLAVE; RESET SLAVE ALL;"` và tắt `read_only` (`SET GLOBAL read_only=0;`).
3. Trên .71 sửa cả 2 config: `192.168.78.223` → `192.168.78.71` (hoặc `127.0.0.1`), bật lại cron (`cdr.cron.enable=true`, `is.send_notify=1`, các `app.*-scanning` về lịch gốc).
4. `sudo supervisorctl restart IcpassCCSP IcpassCMS`.
5. Khi 223 quay lại: cấu hình 223 thành replica/slave của .71, hoặc đảo lại như ban đầu ngoài giờ.

### Việc nên đưa vào backlog dev

- `RedisConfig` của CCSP: đọc `spring.redis.password` + hỗ trợ `RedisSentinelConfiguration` → bật lại `requirepass` và failover tự động.
- Cơ chế lock phân tán (ShedLock hoặc `SET NX` trên Redis) cho các cron → bật cron trên cả 2 node mà không chạy trùng.
- Đặt `ddl-auto=validate` sau khi schema ổn định.

---

## 12. Xử lý sự cố riêng cho node 2

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| `READONLY You can't write against a read only replica` | Config trỏ Redis `localhost`/`.71` | Đổi `spring.redis.host` / `spring.data.redis.host` về `192.168.78.223` |
| `The MariaDB server is running with the --read-only option` | Datasource trỏ MariaDB slave | Đổi URL về `192.168.78.223:3306` |
| `Access denied for user 'gameasy'@'192.168.78.71'` | Chưa GRANT cho IP .71 | Mục 1 |
| `Communications link failure` tới 223 | ufw trên 223 chặn 3306/6379 từ .71 | Mục 1 |
| Telegram nhận cảnh báo gấp đôi | Cron CMS chưa tắt trên node 2 | Mục 7, `app.*-scanning: "-"` |
| CDR xử lý 2 lần | `cdr.cron.enable` chưa `false` trên node 2 | Mục 6 |
| `Unable to connect to Redis` | Redis master bind/firewall | Trên 223: `ss -lntp \| grep 6379`, `ufw status` |