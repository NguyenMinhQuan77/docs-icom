# =====================================================================
# BƯỚC 1: VÔ HIỆU HÓA CRAMFS & UDF (Đạt mục 1.1.1.1, 1.1.1.3: +2 mục)
# =====================================================================
cat << 'EOF' > /etc/modprobe.d/safe-disable.conf
install cramfs /bin/false
install udf /bin/false
EOF

# =====================================================================
# BƯỚC 2: BẢO MẬT PHÂN VÙNG /dev/shm (Đạt mục 1.1.6 -> 1.1.9: +4 mục)
# =====================================================================
if ! grep -qE '\s/dev/shm\s' /etc/fstab; then
    echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0" >> /etc/fstab
fi
mount -o remount,nodev,nosuid,noexec /dev/shm

# =====================================================================
# BƯỚC 3: CÀI ĐẶT VÀ HẸN GIỜ AIDE (Đạt mục 1.2.1, 1.2.2: +2 mục)
# =====================================================================
apt-get update && apt-get install -y aide aide-common
aideinit -y -f 2>/dev/null || true

cat << 'EOF' > /etc/cron.daily/aide
#!/bin/bash
/usr/bin/aide --check
EOF
chmod 755 /etc/cron.daily/aide

# =====================================================================
# BƯỚC 4: GỠ BỎ BIND9 (Đạt mục 2.1.7: +1 mục)
# (Lưu ý: Không ảnh hưởng systemd-resolved phân giải DNS thông thường)
# =====================================================================
systemctl stop bind9 2>/dev/null || true
apt-get purge -y bind9 bind9utils 2>/dev/null || true

# =====================================================================
# BƯỚC 5: THÊM RULE IPTABLES CHO PORT 123 (Đạt mục 3.3.6.1: +1 mục)
# =====================================================================
iptables -I INPUT -p udp --dport 123 -j ACCEPT

# =====================================================================
# BƯỚC 6: CẤU HÌNH SSHD (Đạt mục 3.4.3, 3.4.5: +2 mục)
# =====================================================================
sed -i '/^LogLevel/d' /etc/ssh/sshd_config
sed -i '/^MaxAuthTries/d' /etc/ssh/sshd_config
echo "LogLevel INFO" >> /etc/ssh/sshd_config
echo "MaxAuthTries 4" >> /etc/ssh/sshd_config
sshd -t && systemctl restart sshd

# =====================================================================
# BƯỚC 7: CẤU HÌNH PAM MẬT KHẨU (Đạt mục 3.6.1.2, 3.6.1.3, 3.6.1.4: +3 mục)
# =====================================================================
# Tạo file lưu lịch sử mật khẩu cũ:
touch /etc/security/opasswd
chmod 600 /etc/security/opasswd

# Đảm bảo pam_unix trong common-password có sha512 và remember=5:
sed -i 's/pam_unix.so.*/pam_unix.so obscure use_authtok try_first_pass sha512 remember=5/' /etc/pam.d/common-password

# Cấu hình pam_faillock trong common-auth:
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
# =====================================================================
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
chage -M 90 root
chage -M 90 icom

iptables -I INPUT -p tcp --dport 2223 -j ACCEPT