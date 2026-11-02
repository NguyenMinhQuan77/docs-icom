# Hướng dẫn Cài đặt và Cấu hình RabbitMQ Cluster (Node 71 & 223)

Tài liệu này hướng dẫn cách thiết lập một cụm RabbitMQ (Cluster) gồm 2 node (Active/Active) để đảm bảo tính sẵn sàng cao (High Availability). 

**Giả định môi trường:**
* **Node 1:** IP `192.168.X.71` - Hostname: `rabbit1`
* **Node 2:** IP `192.168.X.223` - Hostname: `rabbit2`
*(Vui lòng thay thế dải IP `192.168.X.` bằng dải mạng thực tế của bạn).*

---

## BƯỚC 1: Cấu hình Hostname (Rất quan trọng)
RabbitMQ Cluster giao tiếp và định tuyến với nhau hoàn toàn thông qua hostname. Bạn bắt buộc phải cấu hình file hosts trên **cả 2 server**.

1. Đổi hostname trên Node 1 (.71):
```bash
sudo hostnamectl set-hostname rabbit1
```
2. Đổi hostname trên Node 2 (.223):
```bash
sudo hostnamectl set-hostname rabbit2
```
3. Mở file `/etc/hosts` trên **CẢ 2 NODE** và thêm 2 dòng sau vào cuối:
```text
192.168.X.71   rabbit1
192.168.X.223  rabbit2
```
*(Kiểm tra: Đứng từ con 71 gõ `ping rabbit2` thấy reply là OK và ngược lại).*

---

## BƯỚC 2: Cài đặt RabbitMQ (Trên cả 2 Node)

Chạy các lệnh sau trên cả 2 máy chủ để cài đặt Erlang và RabbitMQ:

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt Erlang và RabbitMQ
sudo apt install erlang rabbitmq-server -y

# Bật service khởi động cùng hệ thống
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server
```

---

## BƯỚC 3: Đồng bộ Erlang Cookie

RabbitMQ sử dụng một file khóa bí mật gọi là `erlang.cookie` để xác thực giữa các node trong cluster. **Các node phải có cookie giống hệt nhau mới join được.**

1. **Trên Node 1 (.71)**, đọc nội dung chuỗi cookie:
```bash
sudo cat /var/lib/rabbitmq/.erlang.cookie
# Copy chuỗi ký tự hiển thị ra (ví dụ: ABCDEFGHIJKLMN...)
```

2. **Trên Node 2 (.223)**, xóa cookie cũ và thay bằng cookie của Node 1:
```bash
# Dừng rabbitmq trên node 2
sudo systemctl stop rabbitmq-server

# Ghi đè cookie (Thay chuỗi ABC... bằng chuỗi bạn vừa copy)
echo "CHUỖI_COOKIE_CỦA_NODE_1" | sudo tee /var/lib/rabbitmq/.erlang.cookie

# Chỉnh lại quyền chuẩn cho file cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie

# Khởi động lại rabbitmq
sudo systemctl start rabbitmq-server
```

---

## BƯỚC 4: Tham gia Cluster (Thực hiện trên Node 2 - .223)

Bây giờ chúng ta sẽ bảo Node 2 join vào Node 1. Chạy tuần tự các lệnh sau trên **Node 2**:

```bash
# Tạm dừng app rabbitmq (không dừng tiến trình nền)
sudo rabbitmqctl stop_app

# Reset cấu hình tạm
sudo rabbitmqctl reset

# Xin join vào cluster của rabbit1
sudo rabbitmqctl join_cluster rabbit@rabbit1

# Khởi động lại app
sudo rabbitmqctl start_app
```

**Kiểm tra trạng thái Cluster (Chạy trên node nào cũng được):**
```bash
sudo rabbitmqctl cluster_status
```
*Kết quả thành công: Bạn sẽ thấy phần `Nodes` và `Running Nodes` hiển thị cả `rabbit@rabbit1` và `rabbit@rabbit2`.*

---

## BƯỚC 5: Kích hoạt Giao diện Web (Management UI)

Để tiện quản lý bằng trình duyệt, chạy lệnh sau trên **cả 2 Node**:
```bash
sudo rabbitmq-plugins enable rabbitmq_management
```

RabbitMQ mặc định chỉ cho tài khoản `guest` đăng nhập từ localhost. Cần tạo tài khoản admin mới:
```bash
# Tạo user admin (chỉ cần chạy trên 1 node vì cluster đã đồng bộ)
sudo rabbitmqctl add_user admin YourSecretPassword123
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
```
*Bây giờ bạn có thể truy cập web UI qua IP: `http://192.168.X.71:15672` hoặc `.223:15672`*

---

## BƯỚC 6: Cấu hình High Availability (HA Policy)

Mặc định khi bạn tạo 1 Queue, nó chỉ nằm ở Node tạo ra nó. Để RabbitMQ tự động nhân bản (mirror) tất cả các Queue sang tất cả các Node (để nếu 1 node chết, dữ liệu không mất), bạn chạy lệnh sau (chỉ cần chạy trên 1 node):

```bash
sudo rabbitmqctl set_policy ha-all ".*" '{"ha-mode":"all"}'
```
*Kiểm tra:* Vào Web UI -> Tab **Admin** -> **Policies**, bạn sẽ thấy policy `ha-all` đã được kích hoạt thành công.