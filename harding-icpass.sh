#!/bin/bash

# Script gia cố (hardening) Ubuntu 22.04 với backup các file cấu hình
# Chạy script này với quyền root. Một số thay đổi có thể yêu cầu reboot hoặc can thiệp thủ công (như partition).
# Cảnh báo: Script này sẽ thực hiện thay đổi hệ thống. Các file cấu hình sẽ được backup trước khi chỉnh sửa.

# Tạo thư mục backup
BACKUP_DIR="/root/hardening_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Thư mục backup: $BACKUP_DIR"

# Hàm backup file
backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
        echo "Đã sao lưu $file vào $BACKUP_DIR/$(basename "$file").bak"
    else
        echo "File $file không tồn tại, bỏ qua backup."
    fi
}

OS_VERSION=$(awk -F= '/^VERSION_ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

if [[ "$OS_VERSION" == "22.04" ]]; then
    echo "Gia cố trên Ubuntu 22.04"

    

    echo "============================================================"
    echo "MUC GIA CO: 1.3.1 - Gioi han coredump"
    backup_file "/etc/security/limits.conf"
    echo "* hard core 0" >> /etc/security/limits.conf
    backup_file "/etc/sysctl.conf"
    sysctl -w fs.suid_dumpable=0
    echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
    systemctl disable systemd-coredump 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.3.2 - Khoi dong vi tri vung nho ao tu dong"
    backup_file "/etc/sysctl.conf"
    sysctl -w kernel.randomize_va_space=2
    echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.3.3 - Dam bao prelink khong duoc cai dat"
    apt remove -y prelink 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.4.1.1 - Dam bao AppArmor duoc cai dat (thay cho SELinux)"
    apt install -y apparmor
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.4.1.2 - Thiet lap chinh sach AppArmor"
    aa-enforce /etc/apparmor.d/*
    echo "Đã gia cố (reboot để apply)."

    echo "============================================================"
    echo "MUC GIA CO: 1.4.1.3 - Dam bao AppArmor duoc bat"
    systemctl enable apparmor
    systemctl start apparmor
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.5.1 - Thiet lap banner canh bao cho cac dich vu dang nhap"
    backup_file "/etc/motd"
    backup_file "/etc/issue"
    backup_file "/etc/issue.net"
    echo "Authorized users only. All activity may be monitored and reported." > /etc/motd
    echo "Authorized users only. All activity may be monitored and reported." > /etc/issue
    echo "Authorized users only. All activity may be monitored and reported." > /etc/issue.net
    chmod 644 /etc/motd /etc/issue /etc/issue.net
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.5.2 - Loai bo thong tin he dieu hanh khoi banner"
    backup_file "/etc/motd"
    backup_file "/etc/issue"
    backup_file "/etc/issue.net"
    sed -i 's/\\v//g; s/\\r//g; s/\\m//g; s/\\s//g' /etc/motd /etc/issue /etc/issue.net
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 1.6 - Dam bao updates, patches, security software duoc cai dat"
    apt update && apt upgrade -y
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.1.1 - Dam bao thoi gian duoc dong bo"
    apt install -y chrony
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.1.2 - Dam bao dich vu chrony duoc cau hinh"
    backup_file "/etc/chrony/chrony.conf"
    echo "server 10.247.251.10" >> /etc/chrony/chrony.conf
    echo "server 10.247.252.250" >> /etc/chrony/chrony.conf
    echo "server 10.247.255.10" >> /etc/chrony/chrony.conf
    systemctl restart chrony
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.1.3 - Dam bao dich vu ntpd duoc cau hinh"
    apt install -y ntp
    systemctl enable ntp
    systemctl start ntp
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.1.4 - Go bo dich vu xinetd"
    apt remove -y xinetd 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.2 - Go bo X Windows"
    apt remove -y xserver-xorg* 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.3 - Vo hieu hoa Avahi server"
    apt remove -y avahi-daemon 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.4 - Vo hieu hoa print server CUPS"
    apt remove -y cups 2>/dev/null
    systemctl disable cups 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.5 - Go bo DHCP server"
    apt remove -y isc-dhcp-server 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.6 - Go bo LDAP"
    apt remove -y slapd 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.7 - Go bo DNS Server"
    apt remove -y bind9 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.8 - Go bo FTP Server"
    apt remove -y vsftpd 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.9 - Go bo HTTP Server"
    apt remove -y apache2 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.10 - Go bo dovecot (dich vu IMAP và POP3)"
    apt remove -y dovecot-core 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.11 - Go bo Samba"
    apt remove -y samba 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.12 - Go bo HTTP Proxy server"
    apt remove -y squid 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.13 - Go bo dich vu NIS server"
    apt remove -y nis 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.14 - Go bo dich vu telnet server"
    apt remove -y telnetd 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.15 - Cau hinh MTA (Mail Transfer Agent) cho che do local-only"
    apt install -y postfix
    backup_file "/etc/postfix/main.cf"
    sed -i 's/inet_interfaces = all/inet_interfaces = localhost/' /etc/postfix/main.cf
    systemctl restart postfix
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.1.16 - Vo hieu hoa NFS và RPC"
    systemctl disable nfs-server rpcbind 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.2.1 - Go bo dich vu NIS client"
    apt remove -y nis 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.2.2 - Go bo dich vu rsh"
    apt remove -y rsh-client 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.2.3 - Go bo dich vu talk"
    apt remove -y talk 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 2.2.4 - Go bo Ldap client"
    apt remove -y ldap-utils 2>/dev/null
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.1.1 - Vo hieu hoa IP Forwarding"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.ip_forward=0
    echo "net.ipv4.ip_forward = 0" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.1.2 - Vo hieu hoa redirects goi tin gui"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.conf.all.send_redirects=0
    sysctl -w net.ipv4.conf.default.send_redirects=0
    echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.1 - Vo hieu hoa Source Routed Packet Acceptance"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.conf.all.accept_source_route=0
    sysctl -w net.ipv4.conf.default.accept_source_route=0
    echo "net.ipv4.conf.all.accept_source_route = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.2 - Vo hieu hoa ICMP Redirect Acceptance"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.conf.all.accept_redirects=0
    sysctl -w net.ipv4.conf.default.accept_redirects=0
    echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.3 - Vo hieu hoa Secure ICMP Redirect Acceptance"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.conf.all.secure_redirects=0
    sysctl -w net.ipv4.conf.default.secure_redirects=0
    echo "net.ipv4.conf.all.secure_redirects = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.secure_redirects = 0" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.4 - Log cac goi tin khong dang tin cay"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.conf.all.log_martians=1
    sysctl -w net.ipv4.conf.default.log_martians=1
    echo "net.ipv4.conf.all.log_martians = 1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.log_martians = 1" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.5 - Kich hoat Ignore Broadcast Requests"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.6 - Kich hoat Bad Error Message Protection"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1
    echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.7 - Kich hoat RFC-recommended Source Route Validation"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.conf.all.rp_filter=1
    sysctl -w net.ipv4.conf.default.rp_filter=1
    echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.rp_filter = 1" >> /etc/sysctl.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.2.8 - Kich hoat TCP SYN cookies"
    backup_file "/etc/sysctl.conf"
    sysctl -w net.ipv4.tcp_syncookies=1
    echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
    echo "Đã gia cố."

    

    echo "============================================================"
    echo "MUC GIA CO: 3.3.6 - Enable Firewall"
    apt install -y ufw
    ufw enable
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.3.6.1 - Dam bao rule ufw ton tai cho tat ca cac port dang mo"
    for port in $(ss -4tuln | grep -oP ':\K[0-9]+' | sort -u); do
        ufw allow $port/tcp
    done
    ufw reload
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.4.1 - Cau hinh quyen cho file /etc/ssh/sshd_config"
    backup_file "/etc/ssh/sshd_config"
    chmod 644 /etc/ssh/sshd_config
    echo "watch /etc/ssh/sshd_config" > /etc/audit/audit.rules
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.4.2 - Cau hinh giao thuc SSH su dung SSHv2"
    backup_file "/etc/ssh/sshd_config"
    sed -i 's/^Protocol.*/Protocol 2/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.4.3 - Cau hinh LogLevel cho may chu SSH"
    backup_file "/etc/ssh/sshd_config"
    sed -i 's/^LogLevel.*/LogLevel INFO/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.4.4 - Cau hinh vo hieu hoa X11 Forwarding cho may chu SSH"
    backup_file "/etc/ssh/sshd_config"
    sed -i 's/^X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.4.5 - Set SSH MaxAuthTries to 4 or Less"
    backup_file "/etc/ssh/sshd_config"
    sed -i 's/^MaxAuthTries.*/MaxAuthTries 4/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.4.6 - Dam bao viec dang nhap root qua SSH bi vo hieu hoa"
    backup_file "/etc/ssh/sshd_config"
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.5.1.1 - Cau hinh kich hoat rsyslog service"
    apt install -y rsyslog
    systemctl enable rsyslog
    systemctl start rsyslog
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.5.1.2 - Phan quyen doi voi file log sinh ra tu rsyslog"
    backup_file "/etc/rsyslog.conf"
    echo '$FileCreateMode 0640' >> /etc/rsyslog.conf
    systemctl restart rsyslog
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.5.2.1 - Dam bao auditd duoc cai dat"
    apt install -y auditd audispd-plugins
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.5.2.2 - Dam bao auditd duoc kich hoat va dang chay"
    systemctl enable auditd
    systemctl start auditd
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.6.1.1 - Cau hinh dieu kien tao mat khau"
    apt install -y libpam-pwquality
    backup_file "/etc/security/pwquality.conf"
    echo "minlen = 14" >> /etc/security/pwquality.conf
    echo "minclass = 4" >> /etc/security/pwquality.conf
    echo "dcredit = -1" >> /etc/security/pwquality.conf
    echo "ucredit = -1" >> /etc/security/pwquality.conf
    echo "lcredit = -1" >> /etc/security/pwquality.conf
    echo "ocredit = -1" >> /etc/security/pwquality.conf
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.6.1.2 - Cau hinh khoa truy cap do nhieu lan nhap mat khau that bai"
    apt install -y fail2ban
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.6.1.3 - Gioi han viec su dung lai mat khau"
    backup_file "/etc/pam.d/common-password"
    sed -i 's/\(password\s\+[a-z]*\s\+pam_unix.so\)/\1 remember=5/' /etc/pam.d/common-password
    touch /etc/security/opasswd
    chown root:root /etc/security/opasswd
    chmod 600 /etc/security/opasswd
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.6.1.4 - Cau hinh thuat toan hash mat khau sang SHA-512"
    backup_file "/etc/pam.d/common-password"
    sed -i 's/\(password\s\+[a-z]*\s\+pam_unix.so\)/\1 sha512/' /etc/pam.d/common-password
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.7.1.1 - Thiet lap ngay het han mat khau"
    backup_file "/etc/login.defs"
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    for user in $(awk -F: '$3 >= 1000 && $7 != "/usr/sbin/nologin" {print $1}' /etc/passwd); do
        chage --maxdays 90 $user
    done
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.7.1.2 - Thiet lap gioi han so ngay toi thieu thay doi mat khau"
    backup_file "/etc/login.defs"
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' /etc/login.defs
    for user in $(awk -F: '$3 >= 1000 && $7 != "/usr/sbin/nologin" {print $1}' /etc/passwd); do
        chage --mindays 7 $user
    done
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.7.1.3 - Thiet lap so ngay canh bao het han mat khau"
    backup_file "/etc/login.defs"
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs
    for user in $(awk -F: '$3 >= 1000 && $7 != "/usr/sbin/nologin" {print $1}' /etc/passwd); do
        chage --warndays 7 $user
    done
    echo "Đã gia cố."

    echo "============================================================"
    echo "MUC GIA CO: 3.7.2 - Khoa cac tai khoan khong hoat dong"
    backup_file "/etc/default/useradd"
    useradd -D -f 35
    for user in $(awk -F: '$3 >= 1000 && $7 != "/usr/sbin/nologin" {print $1}' /etc/passwd); do
        chage --inactive 35 $user
    done
    echo "Đã gia cố."

    sysctl -p
    echo "Gia cố hoàn tất. Các file cấu hình đã được sao lưu tại $BACKUP_DIR. Reboot hệ thống để apply đầy đủ."
else
    echo "Phiên bản không được hỗ trợ bởi script này."
fi