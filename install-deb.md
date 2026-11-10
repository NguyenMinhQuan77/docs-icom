# Hướng dẫn cài Keepalived offline (Ubuntu 22.04) cho cụm Proxy

| Thành phần | Giá trị |
|---|---|
| Proxy 1 (MASTER) | `10.38.218.194` |
| Proxy 2 (BACKUP) | `10.38.218.195` |
| VIP | `10.38.218.196/28` |
| Card mạng | `ens7` (kiểm tra lại bằng `ip -br addr`) |
| Hệ điều hành | Ubuntu 22.04 (jammy), không có internet |
| Hạ tầng | OpenStack (MAC `fa:16:3e:...`) |

Mô hình: Keepalived theo dõi nginx. Nếu nginx trên MASTER chết hoặc máy MASTER sập, VIP `.196` tự chuyển sang BACKUP. Hai máy trao đổi VRRP bằng **unicast**, vì OpenStack và VMware thường chặn multicast.

---

## Bước 1. Tải các file .deb trên máy Windows

Mở **PowerShell** trên máy Windows (không gõ trong phiên SSH):

```powershell
mkdir C:\Users\$env:USERNAME\Downloads\keepalived-debs
cd C:\Users\$env:USERNAME\Downloads\keepalived-debs

$base = "http://archive.ubuntu.com/ubuntu/pool/main"

# Keepalived
Invoke-WebRequest -Uri "$base/k/keepalived/keepalived_2.2.4-0.2build1_amd64.deb" -OutFile "keepalived.deb"

# Thư viện SNMP (keepalived bắt buộc cần, thiếu sẽ lỗi libnetsnmpmibs.so.40)
Invoke-WebRequest -Uri "$base/n/net-snmp/libsnmp40_5.9.1+dfsg-1ubuntu2.10_amd64.deb" -OutFile "libsnmp40.deb"
Invoke-WebRequest -Uri "$base/n/net-snmp/libsnmp-base_5.9.1+dfsg-1ubuntu2.10_all.deb" -OutFile "libsnmp-base.deb"

# Thư viện cảm biến (libsnmp40 cần, server tối giản thường thiếu)
Invoke-WebRequest -Uri "$base/l/lm-sensors/libsensors5_3.6.0-7ubuntu1_amd64.deb" -OutFile "libsensors5.deb"
Invoke-WebRequest -Uri "$base/l/lm-sensors/libsensors-config_3.6.0-7ubuntu1_all.deb" -OutFile "libsensors-config.deb"

dir
```

> **Nếu link báo lỗi 404:** Ubuntu xóa bản cũ khỏi `pool/` khi có bản cập nhật mới. Mở thư mục tương ứng trên trình duyệt, ví dụ `http://archive.ubuntu.com/ubuntu/pool/main/n/net-snmp/`, lấy file có số phiên bản `ubuntu2.x` lớn nhất cho jammy (bản 5.9.1), rồi sửa lại link.
> `libsnmp40` và `libsnmp-base` phải **cùng một phiên bản**.

> **Không cần giải nén file .deb.** Cài thẳng bằng `dpkg -i` ở bước 3.

---

## Bước 2. Copy file lên 2 server proxy

Vẫn trong PowerShell (thêm `-P <port>` nếu SSH không chạy port 22):

```powershell
scp *.deb root@10.38.218.194:/tmp/
scp *.deb root@10.38.218.195:/tmp/
```

Nếu Windows không có lệnh `scp`, dùng **WinSCP**: kéo thả các file vào thư mục `/tmp/` trên server.

---

## Bước 3. Cài đặt (làm trên cả 2 máy)

### 3.1. Kiểm tra các thư viện phụ đã có chưa

```bash
dpkg -l libc6 libglib2.0-0 libip4tc2 libip6tc2 libmagic1 libmnl0 libnftnl11 \
        libnl-3-200 libnl-genl-3-200 libnl-route-3-200 libpcre2-8-0 libssl3 \
        libpci3 libperl5.34 libwrap0 iproute2 2>&1 | grep -E "^ii|no packages"
```

Mỗi dòng bắt đầu bằng `ii` là gói đã có. Dòng nào báo `no packages found matching X` thì quay lại bước 1, tải thêm gói X từ `http://archive.ubuntu.com/ubuntu/pool/main/<chữ cái đầu>/<tên source>/`.

### 3.2. Cài tất cả file .deb trong cùng một lệnh

```bash
cd /tmp
dpkg -i libsensors-config.deb libsensors5.deb libsnmp-base.deb libsnmp40.deb keepalived.deb
```

Nếu `dpkg` báo `depends on X; however: Package X is not installed`, tải thêm gói X, copy lên rồi chạy lại lệnh trên.

### 3.3. Kiểm tra đủ thư viện

```bash
ldd /usr/sbin/keepalived | grep "not found"
keepalived --version
```

Lệnh `ldd` **không in ra gì** là đã đủ thư viện.

---

## Bước 4. Kiểm tra thông tin mạng

```bash
ip -br addr
```

Ví dụ:

```
ens7   UP   10.38.218.194/28 ...
```

Ghi lại **tên card** (`ens7`) và **subnet** (`/28`). VIP phải dùng cùng subnet đó.

Đổi hostname cho dễ phân biệt (VM clone thường giữ hostname cũ):

```bash
hostnamectl set-hostname proxy-01      # trên .195 đặt proxy-02
```

---

## Bước 5. Tạo script kiểm tra nginx (cả 2 máy)

```bash
cat > /etc/keepalived/check_nginx.sh <<'EOF'
#!/bin/bash
pgrep -x nginx > /dev/null || exit 1
exit 0
EOF
chmod +x /etc/keepalived/check_nginx.sh
```

---

## Bước 6. Cấu hình Keepalived

### 6.1. Trên `10.38.218.194` (MASTER)

```bash
cat > /etc/keepalived/keepalived.conf <<'EOF'
global_defs {
    router_id PROXY_194
    enable_script_security
    script_user root
}

vrrp_script chk_nginx {
    script "/etc/keepalived/check_nginx.sh"
    interval 2
    fall 2
    rise 2
    weight -30
}

vrrp_instance VI_PROXY {
    state MASTER
    interface ens7
    virtual_router_id 196
    priority 110
    advert_int 1

    unicast_src_ip 10.38.218.194
    unicast_peer {
        10.38.218.195
    }

    authentication {
        auth_type PASS
        auth_pass Ic0mVip1
    }

    virtual_ipaddress {
        10.38.218.196/28 dev ens7
    }

    track_script {
        chk_nginx
    }
}
EOF
```

### 6.2. Trên `10.38.218.195` (BACKUP)

```bash
cat > /etc/keepalived/keepalived.conf <<'EOF'
global_defs {
    router_id PROXY_195
    enable_script_security
    script_user root
}

vrrp_script chk_nginx {
    script "/etc/keepalived/check_nginx.sh"
    interval 2
    fall 2
    rise 2
    weight -30
}

vrrp_instance VI_PROXY {
    state BACKUP
    interface ens7
    virtual_router_id 196
    priority 100
    advert_int 1

    unicast_src_ip 10.38.218.195
    unicast_peer {
        10.38.218.194
    }

    authentication {
        auth_type PASS
        auth_pass Ic0mVip1
    }

    virtual_ipaddress {
        10.38.218.196/28 dev ens7
    }

    track_script {
        chk_nginx
    }
}
EOF
```

### 6.3. Giải thích các tham số quan trọng

| Tham số | Ý nghĩa |
|---|---|
| `interface ens7` | Tên card thật lấy ở bước 4. Sai tên thì keepalived báo `interface ... doesn't exist` và tự tắt |
| `virtual_router_id 196` | Phải **giống nhau** trên 2 máy và **không trùng** với cụm keepalived nào khác trong cùng mạng |
| `priority` | MASTER 110, BACKUP 100. Máy có priority cao hơn giữ VIP |
| `weight -30` | Khi nginx chết, priority của MASTER giảm 110 → 80, thấp hơn 100 của BACKUP, nên VIP chuyển sang BACKUP |
| `auth_pass` | Tối đa 8 ký tự, giống nhau trên 2 máy |
| `10.38.218.196/28` | Subnet phải khớp subnet của card (`/28`) |

---

## Bước 7. Cấu hình phía OpenStack (bắt buộc)

OpenStack mặc định chặn traffic tới IP không được gán cho port của VM. Nếu bỏ qua bước này, VIP sẽ hiện trên card nhưng **máy khác không ping được**.

Làm bằng OpenStack CLI, hoặc nhờ bên quản trị cloud làm trên Horizon:

```bash
# 1. Tạo port giữ chỗ cho VIP, tránh OpenStack cấp .196 cho VM khác
openstack port create --network <NETWORK> --fixed-ip ip-address=10.38.218.196 vip-proxy

# 2. Thêm VIP vào allowed-address-pairs của port 2 VM
openstack port list --fixed-ip ip-address=10.38.218.194
openstack port list --fixed-ip ip-address=10.38.218.195
openstack port set --allowed-address ip-address=10.38.218.196 <PORT_ID_194>
openstack port set --allowed-address ip-address=10.38.218.196 <PORT_ID_195>

# 3. Cho phép giao thức VRRP (112) giữa 2 máy trong security group
openstack security group rule create --protocol vrrp --remote-ip 10.38.218.192/28 <SECGROUP>
```

Nếu VIP cần truy cập từ Internet qua floating IP, gán floating IP vào **port `vip-proxy`**, không gán vào port của từng VM.

Nếu VM có bật `ufw`:

```bash
ufw allow from 10.38.218.194 proto vrrp
ufw allow from 10.38.218.195 proto vrrp
```

---

## Bước 8. Khởi động (MASTER trước, BACKUP sau)

```bash
systemctl enable keepalived
systemctl restart keepalived
systemctl status keepalived --no-pager
journalctl -u keepalived -n 20 --no-pager
```

Log đúng:
- Trên `.194`: `(VI_PROXY) Entering MASTER STATE`
- Trên `.195`: `(VI_PROXY) Entering BACKUP STATE`

---

## Bước 9. Kiểm tra

```bash
# Trên .194: phải có 10.38.218.196/28
ip -br addr show ens7

# Trên .195: KHÔNG được có .196
ip -br addr show ens7

# Từ một máy khác trong mạng
ping 10.38.218.196
```

> Nếu VIP xuất hiện trên **cả 2 máy** cùng lúc, đây là **split-brain**: 2 máy không nhận được gói VRRP của nhau. Kiểm tra security group (VRRP/112), ufw, `virtual_router_id` và `unicast_peer`.

---

## Bước 10. Test failover

Từ một máy khác, mở sẵn `ping 10.38.218.196` để theo dõi.

```bash
# Trên .194: giả lập nginx chết
systemctl stop nginx

# Trên .195: sau khoảng 4-5 giây VIP phải chuyển sang
ip -br addr show ens7

# Trên .194: bật lại nginx, VIP quay về .194
systemctl start nginx
```

Test thêm trường hợp tắt hẳn máy MASTER (`poweroff` hoặc tắt VM trên OpenStack). VIP cũng phải chuyển sang `.195`.

---

## Bước 11. Đồng bộ cấu hình nginx giữa 2 proxy

Hai proxy phải có **cấu hình nginx và cert SSL giống hệt nhau**. Nếu không, khi VIP chuyển sang `.195`, các domain sẽ lỗi.

Sau mỗi lần sửa nginx trên `.194`:

```bash
rsync -a --delete /etc/nginx/ root@10.38.218.195:/etc/nginx/
rsync -a /etc/letsencrypt/ root@10.38.218.195:/etc/letsencrypt/
ssh root@10.38.218.195 "nginx -t && systemctl reload nginx"
```

Cert Let's Encrypt chỉ gia hạn được trên máy **đang giữ VIP**, nên cần đồng bộ lại cert sau mỗi lần renew.

---

## Xử lý lỗi thường gặp

| Lỗi trong `journalctl -u keepalived` | Nguyên nhân | Cách sửa |
|---|---|---|
| `error while loading shared libraries: libnetsnmpmibs.so.40` | Thiếu gói `libsnmp40` | Cài `libsnmp40` + `libsnmp-base` (bước 1, 3) |
| `Condition check resulted in ... being skipped` | Chưa có `/etc/keepalived/keepalived.conf` | Tạo file config (bước 6) |
| `interface eth0 ... doesn't exist` / `permanent error CONFIG` | Sai tên card mạng | Sửa `interface` và `dev` theo `ip -br addr` |
| `Got notification message from PID ..., but reception only permitted for main PID` | Cảnh báo của systemd | Vô hại, bỏ qua |
| VIP có trên card nhưng không ping được | OpenStack chặn | Thêm allowed-address-pairs (bước 7) |
| VIP có trên cả 2 máy | Split-brain, VRRP bị chặn | Mở VRRP (112) trong security group / ufw |
| `Script ... not executable` / `unsafe permissions` | Quyền của script check | `chmod 755 /etc/keepalived/check_nginx.sh` và chủ sở hữu phải là `root` |

### Lệnh hay dùng

```bash
systemctl status keepalived --no-pager
journalctl -u keepalived -f
ip -br addr show ens7
keepalived -t -f /etc/keepalived/keepalived.conf    # kiểm tra cú pháp config
```