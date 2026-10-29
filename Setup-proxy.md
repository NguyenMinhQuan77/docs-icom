B1: Thêm file config cho domain mới vào /etc/nginx/conf.d/mywebsite.com.conf
```
server {
    listen 80;
    server_name webmoi.congty.com;

    location / {
        proxy_pass http://ip-vm-private:port; 
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
- Kiểm tra 
```
sudo nginx -t
```
- Áp dụng config mới
```
sudo systemctl reload nginx
```
- Trỏ domain vào IP public đại diện cho đóng host của cụm HIC mới