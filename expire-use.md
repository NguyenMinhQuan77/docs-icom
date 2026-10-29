sudo chage -d $(date +%F) hunghv
sudo chage -l hunghv

- kiểm tra xem host jenkin đẫ có file fingerprinter chưa
```
ssh-keygen -F 192.168.200.196 -f /root/.ssh/known_hosts
```
# 2. Lấy fingerprint rồi thêm vào known_hosts
```
ssh-keyscan -T 5 -H 192.168.200.196 >> /root/.ssh/known_hosts
```