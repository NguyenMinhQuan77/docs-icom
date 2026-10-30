# Cài đặt mysqld_exporter monitor MariaDB (systemd)

Tài liệu hướng dẫn cài **mysqld_exporter** (exporter chính thức của Prometheus, dùng được cho MariaDB) chạy dưới dạng systemd service, thu thập metric cho Prometheus/Grafana, bao gồm metric theo từng query (performance_schema digest).

- Port mặc định: `9104`
- Áp dụng cho: Ubuntu/Debian và RHEL/Rocky/AlmaLinux
- Chạy các lệnh với quyền `root` (hoặc `sudo`)

---

## Mục lục

1. [Cấu hình MariaDB](#1-cấu-hình-mariadb)
2. [Tạo user hệ thống](#2-tạo-user-hệ-thống)
3. [Tải và cài binary](#3-tải-và-cài-binary)
4. [File credentials](#4-file-credentials)
5. [Tạo systemd service](#5-tạo-systemd-service)
6. [Mở firewall](#6-mở-firewall)
7. [Kiểm tra](#7-kiểm-tra)
8. [Khai báo Prometheus](#8-khai-báo-prometheus)
9. [Grafana & PromQL mẫu](#9-grafana--promql-mẫu)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Cấu hình MariaDB

### 1.1. Tên service MariaDB

Theo hệ thống, tên service database của bạn hiện tại là `mariadb.service`. Tên này sẽ được sử dụng cho các lệnh restart và cấu hình systemd ở Bước 5.

### 1.2. Bật performance_schema

MariaDB **tắt performance_schema mặc định**. Thêm vào file cấu hình:

| OS | File cấu hình |
|---|---|
| Ubuntu/Debian | `/etc/mysql/mariadb.conf.d/50-server.cnf` |
| RHEL/Rocky | `/etc/my.cnf.d/server.cnf` |

```ini
[mysqld]
performance_schema = ON
performance-schema-consumer-events-statements-current = ON
performance-schema-consumer-events-statements-history = ON
performance-schema-consumer-statements-digest = ON
```

Restart MariaDB:

```bash
systemctl restart mariadb
mysql -e "SHOW VARIABLES LIKE 'performance_schema';"
```

Kết quả phải là `ON`.

### 1.3. Tạo user cho exporter

```sql
CREATE USER 'exporter'@'localhost' IDENTIFIED BY 'StrongPass@123' WITH MAX_USER_CONNECTIONS 3;
CREATE USER 'exporter'@'127.0.0.1' IDENTIFIED BY 'StrongPass@123' WITH MAX_USER_CONNECTIONS 3;

GRANT PROCESS, REPLICATION CLIENT, SLAVE MONITOR, SELECT ON *.* TO 'exporter'@'localhost';
GRANT PROCESS, REPLICATION CLIENT, SLAVE MONITOR, SELECT ON *.* TO 'exporter'@'127.0.0.1';
FLUSH PRIVILEGES;
```

> **Lưu ý**
> - MariaDB coi `localhost` (socket) và `127.0.0.1` (TCP) là 2 host khác nhau, nên tạo user cho cả hai.
> - Đổi `StrongPass@123` thành mật khẩu thật.

---

## 2. Tạo user hệ thống

### Ubuntu/Debian

Trên một số máy Debian/Ubuntu, `useradd` trỏ tới script `adduser` nên không nhận cú pháp `-g/-s/-M`. Dùng `adduser`:

```bash
addgroup --system mysqld_exporter
adduser --system --ingroup mysqld_exporter --no-create-home \
        --shell /usr/sbin/nologin --disabled-login mysqld_exporter
```

### RHEL/Rocky/AlmaLinux

```bash
groupadd --system mysqld_exporter
useradd --system -g mysqld_exporter -s /sbin/nologin -M mysqld_exporter
```

### Kiểm tra

```bash
id mysqld_exporter
# uid=119(mysqld_exporter) gid=998(mysqld_exporter) groups=998(mysqld_exporter)
```

> Nếu báo `group 'mysqld_exporter' already exists` thì bỏ qua lệnh tạo group, chỉ chạy lệnh tạo user.

---

## 3. Tải và cài binary

```bash
cd /tmp
VER=$(curl -s https://api.github.com/repos/prometheus/mysqld_exporter/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
echo $VER
```

Nếu `echo $VER` không in ra gì (server không ra Internet hoặc bị GitHub rate limit), đặt tay phiên bản lấy từ trang releases:
<https://github.com/prometheus/mysqld_exporter/releases>

```bash
VER=0.17.2   # ví dụ
```

Tải và cài:

```bash
curl -LO https://github.com/prometheus/mysqld_exporter/releases/download/v${VER}/mysqld_exporter-${VER}.linux-amd64.tar.gz
tar xzf mysqld_exporter-${VER}.linux-amd64.tar.gz
install -m 0755 mysqld_exporter-${VER}.linux-amd64/mysqld_exporter /usr/local/bin/
mysqld_exporter --version
```

> Server không có Internet: tải file `.tar.gz` ở máy khác rồi `scp` lên `/tmp`, sau đó chạy từ lệnh `tar`.

---

## 4. File credentials

```bash
mkdir -p /etc/mysqld_exporter

cat > /etc/mysqld_exporter/.my.cnf <<'EOF'
[client]
user=exporter
password=StrongPass@123
socket=/run/mysqld/mysqld.sock
EOF

chown -R mysqld_exporter:mysqld_exporter /etc/mysqld_exporter
chmod 700 /etc/mysqld_exporter
chmod 600 /etc/mysqld_exporter/.my.cnf
```

Test kết nối bằng user exporter:

```bash
mysql --defaults-file=/etc/mysqld_exporter/.my.cnf -e "SELECT CURRENT_USER(), VERSION();"
```

---

## 5. Tạo systemd service

Chạy kịch bản sau để tạo service file với thông số chuẩn đã bao gồm `After=mariadb.service`:

```bash
cat > /etc/systemd/system/mysqld_exporter.service <<'EOF'
[Unit]
Description=Prometheus MySQL/MariaDB Exporter
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
Type=simple
User=mysqld_exporter
Group=mysqld_exporter
ExecStart=/usr/local/bin/mysqld_exporter \
  --config.my-cnf=/etc/mysqld_exporter/.my.cnf \
  --web.listen-address=0.0.0.0:9104 \
  --collect.global_status \
  --collect.global_variables \
  --collect.info_schema.processlist \
  --collect.info_schema.innodb_metrics \
  --collect.info_schema.tables \
  --collect.info_schema.tablestats \
  --collect.binlog_size \
  --collect.slave_status \
  --collect.perf_schema.eventsstatements \
  --collect.perf_schema.eventsstatements.limit=250 \
  --collect.perf_schema.eventsstatements.digest_text_limit=500 \
  --collect.perf_schema.eventsstatementssum \
  --collect.perf_schema.eventswaits \
  --collect.perf_schema.file_events \
  --collect.perf_schema.indexiowaits \
  --collect.perf_schema.tableiowaits \
  --collect.perf_schema.tablelocks
Restart=on-failure
RestartSec=5s

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
```

Khởi động:

```bash
systemctl daemon-reload
systemctl enable --now mysqld_exporter
systemctl status mysqld_exporter
```

### Ý nghĩa các collector chính

| Flag | Dữ liệu |
|---|---|
| `global_status`, `global_variables` | Connections, QPS, buffer pool, threads… |
| `info_schema.processlist` | Số thread theo trạng thái |
| `info_schema.innodb_metrics` | Metric chi tiết InnoDB |
| `info_schema.tables` / `tablestats` | Kích thước bảng, row đọc/ghi (**nặng** nếu nhiều bảng) |
| `slave_status` | Replication lag |
| `perf_schema.eventsstatements` | Metric theo từng query (digest): số lần chạy, lỗi, thời gian |
| `eventsstatements.digest_text_limit` | Độ dài câu query hiển thị (mặc định 120, bị cắt ngắn) |
| `perf_schema.*waits`, `tablelocks` | I/O wait, lock theo bảng/index |

> Muốn dùng `--collect.info_schema.userstats` thì phải bật `userstat = 1` trong MariaDB.

---

## 6. Mở firewall

Chỉ cho phép IP của Prometheus server (thay `10.0.0.10` bằng IP của server Prometheus của bạn):

**ufw (Ubuntu/Debian)**

```bash
ufw allow from 10.0.0.10 to any port 9104 proto tcp
```

**firewalld (RHEL/Rocky)**

```bash
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.10 port port=9104 protocol=tcp accept'
firewall-cmd --reload
```

---

## 7. Kiểm tra

```bash
# Exporter kết nối được DB -> giá trị 1
curl -s localhost:9104/metrics | grep -E '^mysql_up'

# Có metric theo query
curl -s localhost:9104/metrics | grep mysql_perf_schema_events_statements_total | head

# Xem log
journalctl -u mysqld_exporter -f
```

---

## 8. Khai báo Prometheus

Thêm vào `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'mariadb-hci'
    scrape_interval: 15s
    static_configs:
      - targets: ['192.168.200.165:9104']
        labels:
          env: production
          cluster: mariadb-hci
```

Kiểm tra và reload:

```bash
promtool check config /etc/prometheus/prometheus.yml
systemctl reload prometheus
# hoặc: curl -X POST http://localhost:9090/-/reload   (cần --web.enable-lifecycle)
```

Vào `http://<prometheus>:9090/targets` để xác nhận target ở trạng thái **UP**.

> Cluster nhiều node (Galera): cài exporter trên **từng node** và khai báo đủ các target. Metric `mysql_global_status_wsrep_*` dùng để theo dõi trạng thái cluster.

---

## 9. Grafana & PromQL mẫu

### Dashboard import sẵn

- **7362** – MySQL Overview
- **14057** – MySQL (mysqld_exporter)

### Metric theo query (label: `schema`, `digest`, `digest_text`)

| Metric | Ý nghĩa |
|---|---|
| `mysql_perf_schema_events_statements_total` | Số lần thực thi |
| `mysql_perf_schema_events_statements_errors_total` | Số lần lỗi |
| `mysql_perf_schema_events_statements_seconds_total` | Tổng thời gian thực thi |
| `mysql_perf_schema_events_statements_rows_examined_total` | Số row quét |
| `mysql_perf_schema_events_statements_no_index_used_total` | Số lần không dùng index |
| `mysql_perf_schema_events_statements_tmp_disk_tables_total` | Tmp table ghi ra disk |

### PromQL mẫu

```promql
# Query lỗi trong khoảng thời gian dashboard
increase(mysql_perf_schema_events_statements_errors_total{instance="$instance"}[$__range]) > 0

# Error rate (%)
100 * rate(mysql_perf_schema_events_statements_errors_total{instance="$instance"}[5m])
    / rate(mysql_perf_schema_events_statements_total{instance="$instance"}[5m])

# Query chiếm nhiều thời gian DB nhất ("CPU cores used")
topk(10, rate(mysql_perf_schema_events_statements_seconds_total{instance="$instance"}[5m]))

# Top slow queries (latency trung bình)
topk(10,
  rate(mysql_perf_schema_events_statements_seconds_total{instance="$instance"}[5m])
  / rate(mysql_perf_schema_events_statements_total{instance="$instance"}[5m]))

# Query không dùng index
topk(10, rate(mysql_perf_schema_events_statements_no_index_used_total{instance="$instance"}[5m]))

# QPS tổng
rate(mysql_global_status_queries{instance="$instance"}[5m])

# Connections đang dùng / max
mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100
```

> - Giá trị lẻ (vd `6.25`) là do `increase()` ngoại suy, không phải lỗi.
> - `NaN` xuất hiện khi query không chạy lần nào trong khoảng thời gian (0/0).
> - "CPU cores used" thực chất là **thời gian thực thi cộng dồn/giây**, không phải CPU thật (MariaDB không có cột CPU time trong digest).

---

## 10. Troubleshooting

| Triệu chứng | Nguyên nhân / Cách xử lý |
|---|---|
| `useradd: Option g is ambiguous` | `useradd` đang trỏ tới `adduser` (Debian). Dùng lệnh `adduser` ở Bước 2 hoặc gọi `/usr/sbin/useradd` |
| `group 'mysqld_exporter' already exists` | Bỏ qua, chỉ tạo user |
| `mysql_up 0` | Sai user/pass/host trong `.my.cnf`; hoặc user chỉ tạo cho `localhost` mà kết nối qua `127.0.0.1`. Test bằng lệnh `mysql --defaults-file=...` ở Bước 4 |
| Không có metric `mysql_perf_schema_*` | performance_schema chưa `ON` hoặc chưa restart MariaDB |
| `unknown flag` / không đọc được `DATA_SOURCE_NAME` | Từ v0.15+ bỏ biến môi trường `DATA_SOURCE_NAME`, phải dùng `--config.my-cnf` |
| Service không start, `permission denied` đọc `.my.cnf` | Kiểm tra `chown mysqld_exporter` và `chmod 600` ở Bước 4 |
| Prometheus target `DOWN` | Firewall chưa mở 9104, hoặc sai IP target |
| Exporter làm DB chậm / scrape lâu | Bỏ `info_schema.tables`, `tablestats`; giảm `eventsstatements.limit`; tăng `scrape_interval` |
| Câu query trong Grafana bị cắt ngắn | Tăng `--collect.perf_schema.eventsstatements.digest_text_limit` |

### Lệnh hữu ích

```bash
systemctl restart mysqld_exporter
journalctl -u mysqld_exporter --since "10 min ago"
ss -lntp | grep 9104
curl -s localhost:9104/metrics | grep -c '^mysql_'
```