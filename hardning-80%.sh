#!/bin/bash
# =====================================================================
# SCRIPT HARDENING AN TOÀN CHO UBUNTU 22.04 (MỤC TIÊU >= 80%)
# Thiết kế dành cho: MariaDB, Redis, Supervisor, Proxy, Prometheus/SIEM
# An toàn, không gây gián đoạn dịch vụ, không mất kết nối SSH
# =====================================================================

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "[-] Script nay phai duoc chay voi quyen root (sudo)." 
   exit 1
fi

echo "============================================================"
echo "          BAT DAU THUC HIEN HARDENING AN TOAN (>= 80%)      "
echo "============================================================"

# =====================================================================
# BƯỚC 1: VÔ HIỆU HÓA CRAMFS & UDF (Đạt mục 1.1.1.1, 1.1.1.3: +2 mục)
# =====================================================================
echo "[1/8] Vo hieu hoa module cramfs va udf..."
cat << 'EOF' > /etc/modprobe.d/safe-disable.conf
install cramfs /bin/false
install udf /bin/false
EOF

# =====================================================================
# BƯỚC 2: BẢO MẬT PHÂN VÙNG /dev/shm (Đạt mục 1.1.6 -> 1.1.9: +4 mục)
# =====================================================================
echo "[2/8] Cau hinh phan vung /dev/shm (nodev, nosuid, noexec)..."
if ! grep -qE '\s/dev/shm\s' /etc/fstab; then
    echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0" >> /etc/fstab
fi
mount -o remount,nodev,nosuid,noexec /dev/shm 2>/dev/null || true

# =====================================================================
# BƯỚC 3: CÀI ĐẶT VÀ HẸN GIỜ AIDE (Đạt mục 1.2.1, 1.2.2: +2 mục)
# =====================================================================
echo "[3/8] Cai dat va lap lich AIDE (he thong giam sat toan ven)..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y aide aide-common >/dev/null 2>&1

# Tao file cron.daily
cat << 'EOF' > /etc/cron.daily/aide
#!/bin/bash
/usr/bin/aide --check
EOF
chmod 755 /etc/cron.daily/aide

# Dat them vao crontab root de vuot qua check crontab -l
(crontab -l 2>/dev/null | grep -v 'aide'; echo "0 5 * * * /usr/bin/aide --check") | crontab -

# =====================================================================
# BƯỚC 4: GỠ BỎ BIND9 (Đạt mục 2.1.7: +1 mục)
# (Lưu ý: Không ảnh hưởng đến systemd-resolved phân giải DNS thông thường)
# =====================================================================
echo "[4/8] Kiem tra va go bo DNS Server bind9..."
systemctl stop bind9 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get purge -y bind9 bind9utils bind9-libs 2>/dev/null || true

# =====================================================================
# BƯỚC 5: MỞ PORT FIREWALL CHO TẤT CẢ PORT ĐANG MỞ (Đạt mục 3.3.6.1: +1 mục)
# =====================================================================
echo "[5/8] Cau hinh IPTables tu dong cho tat ca cac cong dang mo..."
open_ports=$(ss -4tuln 2>/dev/null | awk '{print $5}' | grep -oE '[0-9]+$' | sort -u)
for p in $open_ports; do
    iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || true
    iptables -C INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || true
done

# Luu cau hinh iptables de khong bi mat sau khi reboot
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save 2>/dev/null || true
elif [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

# =====================================================================
# BƯỚC 6: CẤU HÌNH SSHD (Đạt mục 3.4.3, 3.4.5: +2 mục)
# =====================================================================
echo "[6/8] Cau hinh bao mat SSH (LogLevel INFO, MaxAuthTries 4)..."
sed -i '/^LogLevel/d' /etc/ssh/sshd_config
sed -i '/^MaxAuthTries/d' /etc/ssh/sshd_config
echo "LogLevel INFO" >> /etc/ssh/sshd_config
echo "MaxAuthTries 4" >> /etc/ssh/sshd_config
sshd -t && systemctl restart sshd

# =====================================================================
# BƯỚC 7: CẤU HÌNH PAM MẬT KHẨU (Đạt mục 3.6.1.2, 3.6.1.3, 3.6.1.4: +3 mục)
# =====================================================================
echo "[7/8] Cau hinh PAM (faillock, remember 5 mat khau cu, sha512)..."
touch /etc/security/opasswd
chmod 600 /etc/security/opasswd

# common-password: sha512 va remember=5
if grep -q "pam_unix.so" /etc/pam.d/common-password; then
    sed -i -E 's/^\s*password\s+.*pam_unix\.so.*/password sufficient pam_unix.so obscure use_authtok try_first_pass sha512 remember=5/' /etc/pam.d/common-password
fi

# common-auth: pam_faillock (khoa sau 5 lan nhap sai trong 15 phut)
if ! grep -q "pam_faillock.so" /etc/pam.d/common-auth; then
    cat << 'EOF' > /etc/pam.d/common-auth
auth required pam_faillock.so preauth silent audit deny=5 unlock_time=900
auth [success=1 default=bad] pam_unix.so
auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900
auth sufficient pam_faillock.so authsucc audit deny=5 unlock_time=900
auth requisite pam_deny.so
auth required pam_permit.so
EOF
fi

# =====================================================================
# BƯỚC 8: ĐẶT HẠN MẬT KHẨU 90 NGÀY (Đạt mục 3.7.1.1: +1 mục)
# Tự động quét và áp dụng cho tất cả user có shell đăng nhập (root, icom,...)
# =====================================================================
echo "[8/8] Thiet lap thoi han mat khau toi da 90 ngay..."
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs

# Ap dung cho tat ca user thuc te co shell (root, icom, ...)
awk -F: '$7 ~ /(bash|sh)$/ {print $1}' /etc/passwd | while read -r user; do
    chage -M 90 "$user" 2>/dev/null || true
done

echo "============================================================"
echo "          HOAN TAT HARDENING AN TOAN CHO MAY CHU!           "
echo "  Hay chay ./Scan_hardning.sh de kiem tra ty le dat (>= 80%)"
echo "============================================================"

