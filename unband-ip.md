Bước 3: Xác định IP bị ban
bash
fail2ban-client status            # liệt kê các jail
fail2ban-client status sshd       # xem "Banned IP list"

Nếu không chắc IP của mình, hãy tìm trong log:

bash
grep "Ban " /var/log/fail2ban.log | tail -20
Bước 4: Unban
bash
# Gỡ 1 IP trong 1 jail
fail2ban-client set sshd unbanip 192.168.200.12

# Gỡ IP đó khỏi mọi jail
fail2ban-client unban 192.168.200.12

# Gỡ toàn bộ IP đang bị ban (dùng khi cần mở nhanh)
fail2ban-client unban --all