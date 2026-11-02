# Hướng dẫn Thiết lập HA Nginx và Keepalived (Active/Passive)

Tài liệu này hướng dẫn cài đặt cụm Reverse Proxy độ sẵn sàng cao sử dụng Nginx và Keepalived, trỏ traffic về backend ứng dụng tại `192.168.200.120:8502`.

## Kiến trúc

* **Node 1 (Master):** `192.168.X.11`
* **Node 2 (Backup):** `192.168.X.52`
* **Virtual IP (VIP):** `192.168.X.100` *(Bạn cần đổi IP này thành IP VIP thực tế của mạng nội bộ, domain `ungdatambf.paytech.vn` sẽ trỏ về IP này)*
* **Backend Server:** `192.168.200.120:8502`

---

## BƯỚC 1: Cài đặt phần mềm (Trên cả 2 Node)

Chạy lệnh sau trên cả máy `.11` và `.52` để cài đặt Nginx và Keepalived:

```bash
sudo apt update
sudo apt install nginx keepalived -y
```

---

## BƯỚC 2: Cấu hình Keepalived tạo VIP

### 2.1. Cấu hình trên Node 1 (Master - .11)

Mở file cấu hình Keepalived:
```bash
sudo nano /etc/keepalived/keepalived.conf
```

Dán cấu hình sau (nhớ đổi `eth0` thành tên card mạng của bạn, kiểm tra bằng lệnh `ip a`):
```text
vrrp_script chk_nginx {
    script "killall -0 nginx"   # Kịch bản kiểm tra xem Nginx còn chạy không
    interval 2                  # Kiểm tra mỗi 2 giây
    weight 20
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0              # THAY BẰNG CARD MẠNG THỰC TẾ
    virtual_router_id 51
    priority 100                # Master có priority cao hơn (100)
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111          # Mật khẩu xác thực giữa 2 node
    }
    virtual_ipaddress {
        192.168.X.100           # THAY BẰNG IP VIP THỰC TẾ
    }
    track_script {
        chk_nginx
    }
}
```

### 2.2. Cấu hình trên Node 2 (Backup - .52)

Mở file cấu hình Keepalived trên con `.52`:
```bash
sudo nano /etc/keepalived/keepalived.conf
```

Dán cấu hình sau:
```text
vrrp_script chk_nginx {
    script "killall -0 nginx"
    interval 2
    weight 20
}

vrrp_instance VI_1 {
    state BACKUP                # Khai báo là Backup
    interface eth0              # THAY BẰNG CARD MẠNG THỰC TẾ
    virtual_router_id 51
    priority 90                 # Priority thấp hơn (90)
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.X.100           # THAY BẰNG IP VIP THỰC TẾ
    }
    track_script {
        chk_nginx
    }
}
```

Khởi động lại Keepalived trên cả 2 máy:
```bash
sudo systemctl enable keepalived
sudo systemctl restart keepalived
```

---

## BƯỚC 3: Đồng bộ Chứng chỉ SSL (Quan trọng)

Nginx trên con `.52` cần chứng chỉ SSL y hệt con `.11` để có thể nhận traffic khi xảy ra failover. 
Từ con `.11`, bạn cần copy toàn bộ thư mục Let's Encrypt sang con `.52` (có thể dùng `rsync` hoặc `scp`).

```bash
# Đứng từ con .11 chạy lệnh đẩy thư mục SSL sang con .52
rsync -avz /etc/letsencrypt/ root@192.168.X.52:/etc/letsencrypt/
```
*(Đảm bảo trên con `.52` cũng đã có sẵn các file `options-ssl-nginx.conf` và `ssl-dhparams.pem`)*.

---

## BƯỚC 4: Cấu hình Nginx (Trên cả 2 Node)

File cấu hình bạn cung cấp đã rất chuẩn xác cho mô hình này. Bạn chỉ cần áp dụng nó cho **cả 2 máy**.

Tạo thư mục và file cấu hình trên cả 2 node:
```bash
sudo mkdir -p /etc/nginx/conf.d/ungdatambf
sudo nano /etc/nginx/conf.d/ungdatambf/ungdatambf.paytech.vn.conf
```

Dán toàn bộ nội dung bạn đã có vào:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

# Block 1: Ép HTTPS và hỗ trợ Auto-renew SSL
server {
    listen 80;
    server_name ungdatambf.paytech.vn;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# Block 2: Xử lý HTTPS và Proxy cho Streamlit
server {
    listen 443 ssl;
    server_name ungdatambf.paytech.vn;

    access_log /var/log/nginx/ungdatambf.access.log;
    error_log  /var/log/nginx/ungdatambf.error.log;

    # Đường dẫn SSL chuẩn của tên miền
    ssl_certificate /etc/letsencrypt/live/ungdatambf.paytech.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ungdatambf.paytech.vn/privkey.pem;

    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Whitelist IP
    allow 14.160.70.230;  # icom vnpt
    allow 1.53.252.177;   # icom fpt
    allow 103.88.113.70;  # icom viettel
    allow 210.245.26.44;  # icom hci
    allow 103.35.64.158;  # icom hci
    allow 222.252.25.67;
    allow 10.9.10.1;
    deny all;

    location / {
        proxy_pass http://192.168.200.120:8502;

        # WebSocket cho Streamlit
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Giữ kết nối WebSocket lâu, không buffer
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_buffering off;
    }
}
```

Kiểm tra cú pháp và khởi động lại Nginx (trên cả 2 máy):
```bash
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
```

---

## BƯỚC 5: Kiểm tra tính năng High Availability (HA)

1. **Kiểm tra VIP đang nằm ở đâu:** Trên con Master (`.11`), gõ lệnh `ip a`. Bạn sẽ thấy IP VIP đang gắn trên card mạng của con này. Nhìn sang con `.52` sẽ không thấy VIP.
2. **Kiểm tra Web:** Truy cập vào `https://ungdatambf.paytech.vn` từ mạng nội bộ, ứng dụng Streamlit phải tải bình thường.
3. **Giả lập sự cố (Failover):** Trên con Master (`.11`), giả vờ tắt Nginx đi:
   ```bash
   sudo systemctl stop nginx
   ```
4. **Kiểm tra sự dịch chuyển VIP:** Ngay sau khi Nginx trên `.11` sập, Keepalived sẽ phát hiện và đẩy IP VIP sang con `.52`. Bạn gõ lại `ip a` trên con `.52` sẽ thấy IP VIP xuất hiện. Mở trình duyệt F5 lại web, hệ thống vẫn hoạt động mà không bị gián đoạn.