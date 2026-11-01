# Hướng dẫn Cấu hình Wazuh bắn Cảnh báo (Alert) về Telegram

Tài liệu này hướng dẫn cách tạo một integration (tích hợp) tùy chỉnh trên Wazuh Manager để tự động gửi các cảnh báo bảo mật về một nhóm Telegram.

## Thông tin Bot và Nhóm (Ví dụ)
*   **Bot Token:** `9231229059:AAHOJHB-xgF_r7GVQZFVhcVCd0e8ewZ413s`
*   **Chat ID (Nhóm ICPASS):** `-1004387193192`

*(Lưu ý: Các lệnh dưới đây được thực hiện trên máy chủ **Wazuh Manager - IP 192.168.78.223** bằng quyền `root`)*.

---

## Bước 1: Tạo Script gửi tin nhắn Telegram

Wazuh cần một script Python để định dạng log và đẩy qua API của Telegram. 

1. Mở trình soạn thảo để tạo file script:
   ```bash
   sudo nano /var/ossec/integrations/custom-telegram
   ```

2. Dán đoạn mã Python sau vào file:
   ```python
   #!/var/ossec/framework/python/bin/python3
   import sys
   import json
   import requests

   # Đọc tham số từ Wazuh truyền vào
   alert_file = sys.argv[1]
   token = sys.argv[2]
   chat_id = sys.argv[3]

   # Đọc nội dung file cảnh báo JSON
   with open(alert_file) as f:
       alert = json.load(f)

   # Bóc tách các trường dữ liệu quan trọng
   rule_level = alert.get('rule', {}).get('level', 'N/A')
   rule_id = alert.get('rule', {}).get('id', 'N/A')
   description = alert.get('rule', {}).get('description', 'N/A')
   agent_name = alert.get('agent', {}).get('name', 'N/A')
   agent_ip = alert.get('agent', {}).get('ip', 'N/A')

   # Định dạng tin nhắn gửi đi (Markdown)
   msg = f"🚨 *WAZUH ALERT (Level {rule_level})*\n"
   msg += f"🖥 *Agent:* {agent_name} - {agent_ip}\n"
   msg += f"🏷 *Rule ID:* {rule_id}\n"
   msg += f"📝 *Mô tả:* {description}"

   # Gửi HTTP POST tới Telegram API
   url = f"https://api.telegram.org/bot{token}/sendMessage"
   payload = {
       "chat_id": chat_id,
       "text": msg,
       "parse_mode": "Markdown"
   }
   
   try:
       requests.post(url, json=payload, timeout=10)
   except Exception as e:
       pass
   ```

3. Lưu và thoát (`Ctrl+O` -> `Enter` -> `Ctrl+X`).

---

## Bước 2: Phân quyền cho Script

Script phải thuộc sở hữu của user `wazuh` và có quyền thực thi. Chạy 2 lệnh sau:

```bash
sudo chown root:wazuh /var/ossec/integrations/custom-telegram
sudo chmod 750 /var/ossec/integrations/custom-telegram
```

---

## Bước 3: Khai báo Script vào cấu hình hệ thống

1. Mở file cấu hình chính của Wazuh Manager:
   ```bash
   sudo nano /var/ossec/etc/ossec.conf
   ```

2. Cuộn xuống cuối file, tìm vị trí phía trên thẻ đóng `</ossec_config>` và thêm block `<integration>` sau:

   ```xml
     <!-- Tích hợp cảnh báo qua Telegram -->
     <integration>
       <name>custom-telegram</name>
       <level>7</level>
       <hook_url>-1004387193192</hook_url>
       <api_key>9231229059:AAHOJHB-xgF_r7GVQZFVhcVCd0e8ewZ413s</api_key>
       <alert_format>json</alert_format>
     </integration>
   ```

   **Giải thích cấu hình:**
   * `<level>7</level>`: Chỉ gửi cảnh báo cho các sự kiện có mức độ nghiêm trọng từ 7 trở lên (để tránh spam).
   * `<hook_url>`: Ở đây ta mượn trường này để truyền **Chat ID**.
   * `<api_key>`: Mượn trường này để truyền **Bot Token**.

---

## Bước 4: Khởi động lại Wazuh Manager và Kiểm tra

1. Áp dụng cấu hình mới bằng lệnh:
   ```bash
   sudo systemctl restart wazuh-manager
   ```

2. **Cách Test:** 
   Để kiểm tra xem bot đã hoạt động chưa, hãy tạo ra một hành vi vi phạm bảo mật mức độ 7+ trên máy Agent (VD: IP `.71`). Cách nhanh nhất là giả lập một cú đăng nhập SSH thất bại.
   Đứng trên con Agent `.71`, chạy lệnh sau để ghi log giả mạo:
   ```bash
   logger -p auth.warn "Failed password for invalid user admin from 192.168.78.10 port 22 ssh2"
   ```

Nếu thiết lập thành công, bot `[Alert] ICPASS` sẽ gửi ngay một tin nhắn cảnh báo màu mè vào nhóm của bạn!