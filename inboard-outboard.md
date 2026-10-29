210 scrape metrics 171
- chạy trên 171
sudo iptables -I INPUT 1 -p tcp -s 192.168.200.210 --dport 9100 -j ACCEPT
- chạy trên 210
sudo iptables -I OUTPUT 1 -p tcp -d 192.168.200.171 --dport 9100 -j ACCEPT