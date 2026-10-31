# Hướng dẫn Triển khai Wazuh SIEM và Wazuh Agent

**Mô hình triển khai:**

* **Wazuh Manager (Máy chủ trung tâm SIEM):** `192.168.78.71` (Dùng để xem log, dashboard, phân tích và cảnh báo).
* **Wazuh Agent (Máy được giám sát):** `192.168.78.223` (Nơi phát sinh log, cần theo dõi sự thay đổi file).
* **Hệ điều hành:** Ubuntu 22.04 (Giả định chung cho cả 2 máy).

---

## PHẦN 1: CÀI ĐẶT WAZUH MANAGER (TRÊN IP 192.168.78.71)

Chúng ta sẽ sử dụng kịch bản cài đặt tự động (All-in-one installation) của Wazuh bản 4.9. Yêu cầu máy chủ `.223` có ít nhất 4GB RAM.

### Bước 1: Xử lý xung đột cổng 443 (Quan trọng)
Script cài đặt của Wazuh yêu cầu cổng 443 phải trống. Nếu máy `.223` đang chạy Nginx, Apache hoặc dịch vụ khác trên cổng 443, bạn cần tạm tắt nó:
```bash
# Kiểm tra dịch vụ đang chiếm cổng 443
ss -tulpn | grep :443

# Tạm tắt dịch vụ (Ví dụ nếu là nginx)
systemctl stop nginx
# Hoặc nếu là apache2
systemctl stop apache2
```

### Bước 2: Tải và chạy script cài đặt
Đăng nhập vào máy `192.168.78.71` với quyền `root`. Chạy các lệnh sau:
```bash
# Xóa script cũ nếu có để tránh lỗi XML
rm -f wazuh-install.sh

# Tải script chuẩn bản 4.9
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh

# Chạy cài đặt tự động
bash wazuh-install.sh -a
```
*(Quá trình này sẽ mất khoảng 5-10 phút. Script sẽ tự cài đặt Wazuh Indexer, Wazuh Server, và Wazuh Dashboard).*

### Bước 3: Lưu thông tin đăng nhập
Sau khi chạy xong, màn hình terminal sẽ in ra **Username** (thường là `admin`) và **Password**. **Bạn bắt buộc phải copy và lưu lại mật khẩu này.**

### Bước 4 (Tùy chọn): Đổi cổng Wazuh Dashboard và bật lại dịch vụ cũ
Nếu bạn cần bật lại Nginx/Apache trên cổng 443, hãy đổi cổng của Wazuh sang `8443`:
```bash
# Sửa port trong file cấu hình
nano /etc/wazuh-dashboard/opensearch_dashboards.yml
# Tìm dòng 'server.port: 443' và sửa thành 'server.port: 8443'

# Khởi động lại Dashboard
systemctl restart wazuh-dashboard

# Bật lại dịch vụ cũ của bạn
systemctl start nginx
```

### Bước 5: Truy cập Giao diện điều khiển (Dashboard)
1. Mở trình duyệt web, truy cập: `https://192.168.78.71` (hoặc `https://192.168.78.71:8443` nếu bạn đã đổi cổng ở Bước 4).
2. Bỏ qua cảnh báo SSL (Proceed to unsafe).
3. Đăng nhập bằng `admin` và mật khẩu vừa lưu ở Bước 3.

---

## PHẦN 2: CÀI ĐẶT WAZUH AGENT (TRÊN IP 192.168.78.223)

Đây là máy chúng ta cần giám sát. Chúng ta sẽ cài một phần mềm Agent nhỏ để nó kết nối về con `.223`.

### Bước 1: Thêm Repository của Wazuh
Đăng nhập vào máy `192.168.78.223` với quyền `root`:
```bash
apt-get update
apt-get install -y curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg

# Thêm GPG Key
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg

# Thêm Repo bản 4.9
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.9/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update
```

### Bước 2: Cài đặt và kết nối Agent
Cài đặt Agent và trỏ về IP của máy Manager (`.223`):
```bash
WAZUH_MANAGER="192.168.78.71" apt-get install wazuh-agent -y
```

### Bước 3: Khởi động Agent
```bash
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```
*(Lúc này, con `.71` đã bắt đầu gửi log hệ thống (syslog, auth.log) về cho con `.223`)*

---

## PHẦN 3: CẤU HÌNH THEO DÕI THAY ĐỔI FILE (FIM)

Để giám sát xem có ai đó sửa, xóa, hay tạo file mới trên máy `.71` hay không.

### Bước 1: Chỉnh sửa cấu hình Agent
Đứng trên con Agent (`192.168.78.223`), mở file cấu hình:
```bash
nano /var/ossec/etc/ossec.conf
```

### Bước 2: Thêm thư mục cần theo dõi
Tìm đến thẻ `<syscheck>`. Giả sử bạn muốn theo dõi thư mục web `/var/www/html` theo thời gian thực để chống bị chèn mã độc. Thêm dòng sau vào bên trong thẻ `<syscheck>`:
```xml
<!-- Theo dõi thay đổi thư mục web theo thời gian thực -->
<directories realtime="yes">/var/www/html</directories>
```

### Bước 3: Khởi động lại Agent
```bash
systemctl restart wazuh-agent
```

---

## PHẦN 4: XEM LOG VÀ CẢNH BÁO TRÊN DASHBOARD (.223)

1. **Kiểm tra Agent đã kết nối:**
   Trên web dashboard, click vào logo **Wazuh** -> **Agents**. Bạn sẽ thấy máy `192.168.78.223` ở trạng thái **Active**.

2. **Xem sự kiện Bảo mật (Security Events):**
   Click vào Agent `.71`, chọn tab **Security Events**. Mọi hành động đăng nhập sai mật khẩu (SSH failed login), sudo, hoặc lỗi hệ thống của con `.71` đều được hiện tại đây.

3. **Xem thay đổi File (FIM):**
   Click vào Agent `.71`, chọn tab **Integrity monitoring**.
   *Thử nghiệm:* Vào con `.71`, tạo một file mới bằng lệnh `touch /var/www/html/hacked.php`. Vài giây sau, màn hình Dashboard trên `.223` sẽ báo động đỏ (File added).