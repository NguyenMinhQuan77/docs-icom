# MariaDB HA với Keepalived – Tự động failover khi Master chết

## 1. Tổng quan

| Thành phần | Giá trị |
|---|---|
| Node 1 (master ban đầu) | `10.38.218.194` – hostname `MariaDB-Master-223`, `server_id = 1` |
| Node 2 (slave ban đầu) | `10.38.218.195` – hostname `MariaDB-Slave-71`, `server_id = 2` |
| VIP (ứng dụng kết nối vào đây) | `10.38.218.196/28` |
| Interface | `ens7` |
| MariaDB | 10.6.23 (Ubuntu 22.04) |
| Replication | GTID, SSL (`REQUIRE ISSUER '/CN=Company-DB-CA'`) |

### Mô hình: Master–Master (2 chiều) + Keepalived Active–Passive

- Hai node **replicate qua lại** bằng GTID (194 ⇄ 195).
- Chỉ node **đang giữ VIP** được ghi (`read_only = OFF`); node còn lại `read_only = ON`.
- Keepalived kiểm tra MariaDB mỗi 2s. Nếu MariaDB hoặc server trên node giữ VIP chết, VIP chuyển sang node kia và node đó được mở ghi.
- `nopreempt`: khi node chết bật lại, nó **không** giật lại VIP. Node đó lên ở chế độ read_only và tự kéo dữ liệu còn thiếu qua replication.

**Tại sao phải replicate 2 chiều?** Nếu chỉ master → slave, sau khi failover các dữ liệu ghi trên slave sẽ không quay về master cũ. Lần failover ngược lại sẽ mất dữ liệu.

```
              App ──► VIP 10.38.218.196
                        │
          ┌─────────────┴─────────────┐
   10.38.218.194                10.38.218.195
   MariaDB (RW khi giữ VIP) ⇄  MariaDB (RO khi không giữ VIP)
   keepalived prio 100          keepalived prio 90
```

---

## 2. Yêu cầu hạ tầng (OpenStack)

- Port của cả 2 VM phải có **allowed-address-pairs** chứa `10.38.218.196`.
- Security group cho phép giữa 2 node:
  - **Protocol 112 (VRRP)**
  - **TCP 3306**
- `virtual_router_id` không trùng với cụm keepalived khác trong cùng mạng L2 (cụm nginx cũ).

---

## 3. Cấu hình MariaDB (cả 2 node)

File: `/etc/mysql/mariadb.conf.d/50-server.cnf`, mục `[mysqld]`.

**Node 194:**
```ini
[mysqld]
bind-address              = 0.0.0.0
server_id                 = 1
log_bin                   = mysql-bin
log_slave_updates         = 1
binlog_format             = ROW
relay_log                 = relay-bin
gtid_domain_id            = 0
auto_increment_increment  = 2
auto_increment_offset     = 1
read_only                 = 1      # luôn khởi động ở RO, keepalived sẽ mở ghi

# SSL
ssl_ca   = /etc/mysql/ssl/ca-cert.pem
ssl_cert = /etc/mysql/ssl/master-cert.pem
ssl_key  = /etc/mysql/ssl/master-key.pem
```

**Node 195:** giống hệt, chỉ khác các dòng sau:
```ini
server_id                 = 2
auto_increment_offset     = 2
ssl_cert = /etc/mysql/ssl/replica-cert.pem
ssl_key  = /etc/mysql/ssl/replica-key.pem
```

Áp dụng cấu hình:
```bash
systemctl restart mariadb
```

> **Lưu ý:** `read_only` không chặn user có quyền `SUPER` (root). Ứng dụng phải dùng user thường.

---

## 4. Chứng chỉ SSL

CA và các cert nằm trong `/etc/mysql/ssl/` trên **194** (CA key `ca-key.pem` cũng ở đây).

| File | Dùng cho |
|---|---|
| `ca-cert.pem` / `ca-key.pem` | CA `Company-DB-CA` (cả 2 node cần `ca-cert.pem`, fingerprint phải giống nhau) |
| `master-cert.pem` / `master-key.pem` | Cert server của 194 (SAN có IP 194) |
| `replica-cert.pem` / `replica-key.pem` | Cert client cho replication; trên 195 dùng làm cert server |

Kiểm tra:
```bash
openssl x509 -in /etc/mysql/ssl/ca-cert.pem -noout -subject -fingerprint   # so sánh 2 node
openssl verify -CAfile /etc/mysql/ssl/ca-cert.pem /etc/mysql/ssl/replica-cert.pem
```

Nếu cần tạo cert client mới (trên node có `ca-key.pem`):
```bash
cd /etc/mysql/ssl
openssl genrsa -out client-key.pem 2048
openssl req -new -key client-key.pem -out client.csr -subj "/CN=repl-client"
openssl x509 -req -in client.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out client-cert.pem -days 3650 -sha256
chown mysql:mysql client-*.pem && chmod 600 client-key.pem && rm client.csr
```

---

## 5. User replication

User `repl` phải tồn tại trên **cả 2 node** (mỗi node là master của node kia).

> Server có plugin `simple_password_check`: mật khẩu cần ≥ 8 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt.

Tạo trên từng node mà **không ghi binlog** (tránh lệch GTID):
```sql
SET sql_log_bin = 0;
CREATE USER 'repl'@'10.38.218.%' IDENTIFIED BY '<REPL_PASSWORD>' REQUIRE ISSUER '/CN=Company-DB-CA';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.38.218.%';
FLUSH PRIVILEGES;
SET sql_log_bin = 1;
```

Test đăng nhập chéo (từ 194 sang 195, và ngược lại):
```bash
mariadb -h 10.38.218.195 -u repl -p'<REPL_PASSWORD>' \
  --ssl-ca=/etc/mysql/ssl/ca-cert.pem \
  --ssl-cert=/etc/mysql/ssl/replica-cert.pem \
  --ssl-key=/etc/mysql/ssl/replica-key.pem \
  -e "SELECT 1"
```

---

## 6. Thiết lập replication 2 chiều

### 6.1. Chiều 194 → 195 (195 là slave của 194)

**Trên 195:**
```sql
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='10.38.218.194',
  MASTER_USER='repl',
  MASTER_PASSWORD='<REPL_PASSWORD>',
  MASTER_USE_GTID=slave_pos,
  MASTER_SSL=1,
  MASTER_SSL_CA='/etc/mysql/ssl/ca-cert.pem',
  MASTER_SSL_CERT='/etc/mysql/ssl/replica-cert.pem',
  MASTER_SSL_KEY='/etc/mysql/ssl/replica-key.pem',
  MASTER_SSL_VERIFY_SERVER_CERT=1;
START SLAVE;
```

### 6.2. Đồng bộ GTID binlog state trên 195

Khi binlog của 195 vừa được bật, nó còn trống. Nếu không đồng bộ GTID, 194 sẽ không tìm thấy vị trí bắt đầu và báo lỗi **1236**.

**Trên 194:**
```sql
SELECT @@gtid_binlog_pos;          -- ví dụ: 0-1-112
```

**Trên 195** (chỉ làm khi 195 đã bắt kịp, tức `gtid_slave_pos` bằng giá trị trên):
```sql
SELECT @@gtid_slave_pos;
RESET MASTER;
SET GLOBAL gtid_binlog_state = '0-1-112';
SELECT @@gtid_binlog_pos;          -- phải ra đúng giá trị đó
```

### 6.3. Chiều 195 → 194 (194 là slave của 195)

**Trên 194:**
```sql
SET GLOBAL gtid_slave_pos = '0-1-112';     -- = @@gtid_binlog_pos của 194 (nếu chưa set)
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='10.38.218.195',
  MASTER_USER='repl',
  MASTER_PASSWORD='<REPL_PASSWORD>',
  MASTER_USE_GTID=slave_pos,
  MASTER_SSL=1,
  MASTER_SSL_CA='/etc/mysql/ssl/ca-cert.pem',
  MASTER_SSL_CERT='/etc/mysql/ssl/replica-cert.pem',
  MASTER_SSL_KEY='/etc/mysql/ssl/replica-key.pem',
  MASTER_SSL_VERIFY_SERVER_CERT=0;   -- cert server của 195 không có SAN IP 195
START SLAVE;
```

### 6.4. Kiểm tra

Trên cả 2 node:
```sql
SHOW SLAVE STATUS\G
-- Slave_IO_Running: Yes, Slave_SQL_Running: Yes, Seconds_Behind_Master: 0, Last_*_Error trống
SELECT @@gtid_current_pos;   -- 2 node phải giống nhau
```

Test ghi 2 chiều:
```sql
-- 194
CREATE DATABASE ha_test;
CREATE TABLE ha_test.t2 (id INT, src VARCHAR(10));
INSERT INTO ha_test.t2 VALUES (1, '194');
-- 195
SELECT * FROM ha_test.t2;
INSERT INTO ha_test.t2 VALUES (2, '195');
-- 194
SELECT * FROM ha_test.t2;     -- phải có 2 dòng
DROP DATABASE ha_test;
```

---

## 7. Keepalived

### 7.1. Script check MariaDB (cả 2 node)

`/etc/keepalived/check_mariadb.sh`
```bash
#!/bin/bash
# Fail nếu MariaDB không trả lời trong 3s
timeout 3 mariadb -N -e "SELECT 1" >/dev/null 2>&1 || exit 1
exit 0
```

### 7.2. Script notify – bật/tắt read_only (cả 2 node)

`/etc/keepalived/notify.sh`
```bash
#!/bin/bash
STATE=$3
LOG=/var/log/keepalived-mariadb.log
echo "$(date '+%F %T') -> $STATE" >> $LOG

case $STATE in
  MASTER)
    # Chờ áp hết relay log (tối đa 30s) trước khi mở ghi
    for i in $(seq 1 30); do
      LAG=$(mariadb -e "SHOW SLAVE STATUS\G" | awk '/Seconds_Behind_Master/{print $2}')
      { [ "$LAG" = "0" ] || [ "$LAG" = "NULL" ] || [ -z "$LAG" ]; } && break
      sleep 1
    done
    mariadb -e "SET GLOBAL read_only = 0;" && echo "  read_only=OFF" >> $LOG
    ;;
  BACKUP|FAULT|STOP)
    mariadb -e "SET GLOBAL read_only = 1;" 2>/dev/null && echo "  read_only=ON" >> $LOG
    ;;
esac
```

Phân quyền:
```bash
chmod 700 /etc/keepalived/*.sh
chown root:root /etc/keepalived/*.sh
```

> Keepalived chạy bằng root, root@localhost dùng `unix_socket` nên script không cần mật khẩu.

### 7.3. keepalived.conf

Sao lưu config cũ:
```bash
cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
```

**Node 194** – `/etc/keepalived/keepalived.conf`
```conf
global_defs {
    router_id MARIADB_194
    enable_script_security
    script_user root
}

vrrp_script chk_mariadb {
    script "/etc/keepalived/check_mariadb.sh"
    interval 2
    timeout 5
    fall 3          # 3 lần fail liên tiếp (~6s) -> FAULT, nhả VIP
    rise 2
}

vrrp_instance VI_DB {
    state BACKUP            # cả 2 đều BACKUP để nopreempt có tác dụng
    nopreempt
    interface ens7
    virtual_router_id 61
    priority 100
    advert_int 1

    unicast_src_ip 10.38.218.194
    unicast_peer {
        10.38.218.195
    }

    authentication {
        auth_type PASS
        auth_pass DbVip61
    }

    virtual_ipaddress {
        10.38.218.196/28 dev ens7
    }

    track_script {
        chk_mariadb
    }

    notify /etc/keepalived/notify.sh
}
```

**Node 195:** giống hệt, chỉ đổi 4 chỗ:
```conf
    router_id MARIADB_195
    priority 90
    unicast_src_ip 10.38.218.195
    unicast_peer {
        10.38.218.194
    }
```

### 7.4. Khởi động

Restart keepalived trên 194 trước, sau đó trên 195:
```bash
systemctl restart keepalived
systemctl enable keepalived
```

Kiểm tra:
```bash
ip a show ens7 | grep 196
mariadb -e "SELECT @@read_only;"
tail -f /var/log/keepalived-mariadb.log
journalctl -u keepalived -f
```

Trạng thái mong đợi: **194** giữ VIP và có `read_only = 0`; **195** không có VIP và có `read_only = 1`.

---

## 8. Kịch bản test HA

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 0 | Bình thường | VIP ở 194, 194 RW, 195 RO |
| 1 | Tắt 194 (`poweroff` hoặc `systemctl stop mariadb`) | Sau ~6s VIP sang 195, 195 `read_only=0` |
| 2 | Ghi dữ liệu qua VIP | Dữ liệu nằm trên 195 |
| 3 | Bật lại 194 | 194 lên RO, giữ BACKUP (không lấy lại VIP), tự sync dữ liệu ở bước 2 |
| 4 | `SHOW SLAVE STATUS\G` trên 194 | IO/SQL Yes, lag 0, đủ dữ liệu |
| 5 | Tắt 195 | VIP về 194, 194 RW, dữ liệu đầy đủ |
| 6 | Bật lại 195 | 195 về BACKUP, RO, tự sync từ 194 |

Ghi thử qua VIP bằng một user ứng dụng:
```bash
mariadb -h 10.38.218.196 -u <app_user> -p -e "SELECT @@hostname, @@read_only;"
```

---

## 9. Runbook – Xử lý khi Master chết

### 9.1. Tự động (không cần làm gì)

1. Keepalived trên node chết ngừng gửi VRRP, hoặc script check fail 3 lần.
2. Node còn lại chuyển sang MASTER, nhận VIP `10.38.218.196`.
3. `notify.sh` chờ áp hết relay log rồi `SET GLOBAL read_only = 0`.
4. Ứng dụng kết nối lại qua VIP và tiếp tục ghi.

Xác nhận trên node còn sống:
```bash
ip a show ens7 | grep 196
mariadb -e "SELECT @@read_only;"          # 0
tail /var/log/keepalived-mariadb.log      # có dòng -> MASTER, read_only=OFF
```

### 9.2. Đưa node chết quay lại

1. Bật server, hoặc chạy `systemctl start mariadb`.
2. MariaDB lên với `read_only = 1` (theo config). Keepalived vào BACKUP và **không** lấy lại VIP.
3. Kiểm tra replication tự bắt kịp:
   ```sql
   SHOW SLAVE STATUS\G      -- IO/SQL Yes, Seconds_Behind_Master về 0
   SELECT @@gtid_current_pos;   -- so với node đang giữ VIP
   ```
4. Nếu muốn đưa VIP về node cũ (ví dụ về 194 sau khi bảo trì), làm trong giờ thấp điểm:
   ```bash
   # trên node đang giữ VIP
   systemctl restart keepalived
   ```
   Cách này chỉ thực hiện khi node kia đã sync xong (lag = 0).

### 9.3. Khi replication trên node quay lại bị lỗi

Thường gặp khi master chết đột ngột và một số transaction chưa kịp sang node kia.

- Xem lỗi: `SHOW SLAVE STATUS\G` → `Last_IO_Error`, `Last_SQL_Error`.
- **Không** cho node này nhận VIP cho tới khi xử lý xong. Có thể tạm dừng keepalived trên node lỗi bằng `systemctl stop keepalived`.
- Nếu lệch dữ liệu nhỏ và xác định được, sửa thủ công rồi `START SLAVE`.
- Nếu lệch nhiều, **dựng lại node lỗi từ node đang chạy**:
  1. Trên node đang chạy: `mariadb-backup --backup` (hoặc `mariadb-dump --all-databases --master-data=2 --gtid --single-transaction`).
  2. Restore sang node lỗi.
  3. Đặt `gtid_slave_pos` theo backup, `CHANGE MASTER TO ...` trỏ về node đang chạy, rồi `START SLAVE`.
  4. Trên node đang chạy, cấu hình lại chiều ngược lại (mục 6.2 và 6.3).
  5. Bật lại keepalived trên node vừa dựng.

---

## 10. Troubleshooting – các lỗi đã gặp

| Lỗi | Nguyên nhân | Cách xử lý |
|---|---|---|
| `1045 Access denied for user 'repl'@'10.38.218.194'` | Sai mật khẩu, thiếu cert client, hoặc hash `repl` 2 node khác nhau | So hash: `SELECT PASSWORD('<pw>'), authentication_string FROM mysql.user WHERE user='repl';`. Mật khẩu đang chạy của chiều ngược lại có trong `/var/lib/mysql/master.info` (dòng 6) |
| User có `REQUIRE ISSUER` | Client bắt buộc gửi cert do `Company-DB-CA` ký | Dùng `--ssl-ca`, `--ssl-cert`, `--ssl-key`; trong `CHANGE MASTER` thêm `MASTER_SSL_*` |
| `1396 Operation ALTER/CREATE USER failed` | Thường do mật khẩu bị plugin policy từ chối, hoặc ACL lệch | Kiểm tra với mật khẩu mạnh; nếu cần `DROP USER IF EXISTS` rồi tạo lại (trong `sql_log_bin=0`) |
| `1819 Your password does not satisfy the current policy` | Plugin `simple_password_check` | Dùng mật khẩu ≥ 8 ký tự, có hoa/thường/số/ký tự đặc biệt |
| `1130 Host ... is not allowed to connect` | User `repl` không tồn tại trên node đích | Tạo lại user (mục 5) |
| `1236 ... GTID ... not in the master's binlog` | Binlog của master mới trống hoặc thiếu GTID | `RESET MASTER; SET GLOBAL gtid_binlog_state='<pos>';` (mục 6.2) |
| Lỗi verify certificate khi kết nối replication | Cert server không có SAN IP của node | `MASTER_SSL_VERIFY_SERVER_CERT=0` hoặc cấp lại cert server có `IP:<node ip>` |
| VIP xuất hiện trên cả 2 node (split-brain) | VRRP bị chặn | Mở protocol 112 trong security group, kiểm tra `unicast_peer`, `virtual_router_id` |
| VIP có trên node nhưng không ping được từ ngoài | OpenStack chặn IP lạ | Thêm allowed-address-pairs cho VIP trên cả 2 port |

---

## 11. Lưu ý vận hành

- **Replication là async:** nếu master chết đột ngột, có thể mất vài transaction cuối chưa kịp sang node kia. Muốn chặt hơn, bật semi-sync (`rpl_semi_sync_master_enabled`, `rpl_semi_sync_slave_enabled`).
- **Không bỏ `nopreempt`:** nếu bỏ, node vừa bật lại sẽ giật VIP khi chưa sync xong.
- Không bao giờ ghi trực tiếp vào node không giữ VIP. Ứng dụng luôn đi qua `10.38.218.196`.
- Thao tác quản trị trên user/grant nên chạy trên node giữ VIP để replicate sang node kia, trừ trường hợp cố ý dùng `sql_log_bin=0`.
- Sau khi test xong, đổi mật khẩu `repl` thành mật khẩu riêng và cập nhật `MASTER_PASSWORD` ở cả 2 node.
- Theo dõi định kỳ: `SHOW SLAVE STATUS\G` trên cả 2 node, `/var/log/keepalived-mariadb.log`.