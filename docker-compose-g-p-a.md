# Hướng dẫn Triển khai Hệ thống Giám sát (Prometheus, Alertmanager, Grafana) bằng Docker Compose

Tài liệu này hướng dẫn cách thiết lập nhanh một hệ thống giám sát cơ bản cho các dự án nhỏ. Toàn bộ stack được đóng gói và quản lý bằng Docker Compose, giúp việc cài đặt, sao lưu và di chuyển trở nên dễ dàng.

## 1. Yêu cầu hệ thống
* Server Linux (Ubuntu/CentOS/Debian...)
* Đã cài đặt **Docker** và **Docker Compose**.
* Mở các port sau trên Firewall (nếu cần truy cập từ bên ngoài):
  * `3000`: Giao diện Web Grafana.
  * `9090`: Giao diện Web Prometheus (Tùy chọn, thường chỉ dùng để debug).
  * `9093`: Giao diện Web Alertmanager (Tùy chọn).

## 2. Chuẩn bị cấu trúc thư mục
Tạo một thư mục chính chứa toàn bộ dự án giám sát và các thư mục cấu hình con:

```bash
mkdir -p /opt/monitoring/{prometheus,alertmanager,grafana}
cd /opt/monitoring
```

Cấu trúc cây thư mục cuối cùng sẽ trông như sau:
```text
/opt/monitoring/
├── docker-compose.yml
├── alertmanager/
│   └── alertmanager.yml
└── prometheus/
    └── prometheus.yml
```

## 3. Tạo các file cấu hình

### 3.1. File cấu hình Prometheus
Tạo file `/opt/monitoring/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s # Chu kỳ kéo dữ liệu (mặc định)
  evaluation_interval: 15s # Chu kỳ kiểm tra cảnh báo

# Cấu hình kết nối tới Alertmanager
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'alertmanager:9093' # Dùng tên service trong docker-compose

# Cấu hình các mục tiêu cần giám sát (Targets)
scrape_configs:
  # Giám sát chính bản thân Prometheus
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  
  # Thêm các target khác ở đây (Ví dụ: Node Exporter, MySQL Exporter)
  # - job_name: "linux-server"
  #   static_configs:
  #     - targets: ["192.168.1.100:9100"]
```

### 3.2. File cấu hình Alertmanager
Tạo file `/opt/monitoring/alertmanager/alertmanager.yml`. Đây là cấu hình cơ bản, sau này bạn có thể thêm Webhook (Telegram, Slack, Email) vào đây:

```yaml
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
    # Ví dụ cấu hình gửi qua Telegram (Bỏ comment và điền token/chat_id để dùng)
    # telegram_configs:
    #   - bot_token: 'YOUR_BOT_TOKEN'
    #     chat_id: 'YOUR_CHAT_ID'
```

### 3.3. File cấu hình Docker Compose
Tạo file `/opt/monitoring/docker-compose.yml` chứa định nghĩa 3 dịch vụ:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - monitor-net

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "9093:9093"
    networks:
      - monitor-net

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin       # Đổi user đăng nhập mặc định
      - GF_SECURITY_ADMIN_PASSWORD=admin   # Đổi password đăng nhập mặc định
    ports:
      - "3000:3000"
    networks:
      - monitor-net
    depends_on:
      - prometheus

networks:
  monitor-net:
    driver: bridge

volumes:
  prometheus_data:
  alertmanager_data:
  grafana_data:
```

## 4. Khởi chạy hệ thống

Từ thư mục `/opt/monitoring`, chạy lệnh sau để khởi động toàn bộ stack ở chế độ background (`-d`):

```bash
docker-compose up -d
```

Kiểm tra trạng thái các container:
```bash
docker-compose ps
```

Nếu muốn xem log hệ thống:
```bash
docker-compose logs -f
```

## 5. Hướng dẫn sử dụng sau khi cài đặt

### 5.1. Cấu hình Datasource trên Grafana
1. Mở trình duyệt, truy cập: `http://<IP_SERVER>:3000`
2. Đăng nhập bằng user/pass mặc định: `admin` / `admin` (Hệ thống sẽ yêu cầu bạn đổi mật khẩu mới ngay lần đầu).
3. Ở menu bên trái, vào **Connections** -> **Data sources** -> Click **Add data source**.
4. Chọn **Prometheus**.
5. Ở mục **Prometheus server URL**, nhập: `http://prometheus:9090` (Do chạy chung mạng Docker nên Grafana có thể gọi thẳng tên container).
6. Cuộn xuống dưới cùng và nhấn **Save & Test**. Nếu hiện thông báo xanh "Data source is working" là thành công.

### 5.2. Nhập (Import) Dashboard mẫu
Grafana có một kho dashboard làm sẵn rất phong phú. Nếu bạn cài Node Exporter (giám sát máy chủ) hoặc MySQL/MariaDB Exporter, bạn có thể import dashboard như sau:
1. Vào menu bên trái -> **Dashboards** -> Chọn **New** -> **Import**.
2. Nhập ID của Dashboard (Ví dụ: `1860` cho Node Exporter, `14057` cho MySQL) vào ô *Import via grafana.com*.
3. Nhấn **Load**, chọn Datasource là Prometheus vừa tạo ở bước trên và nhấn **Import**.