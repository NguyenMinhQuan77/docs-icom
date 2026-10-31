# Hướng dẫn Thiết lập Cronjob tự động chạy Script Backup

Cronjob là một công cụ lập lịch tác vụ tự động (task scheduler) được tích hợp sẵn trên các hệ điều hành Linux. Dưới đây là hướng dẫn cách thiết lập cronjob để tự động chạy script backup MariaDB mà không cần bạn phải gõ lệnh thủ công mỗi ngày.

## 1. Cấu trúc cơ bản của Cronjob

Một dòng lệnh cronjob có cấu trúc gồm 5 dấu sao (`*`) đại diện cho thời gian, tiếp theo là lệnh cần chạy:

```text
* * * * * lệnh_cần_chạy
| | | | |
| | | | +---- Ngày trong tuần (0 - 7) (Chủ nhật là 0 hoặc 7)
| | | +------ Tháng (1 - 12)
| | +-------- Ngày trong tháng (1 - 31)
| +---------- Giờ (0 - 23)
+------------ Phút (0 - 59)
```

**Ví dụ:**
* `0 2 * * *` : Chạy vào lúc 2h00 sáng mỗi ngày.
* `30 1 * * 0` : Chạy vào lúc 1h30 sáng mỗi Chủ nhật hàng tuần.
* `0 0,12 * * *` : Chạy 2 lần mỗi ngày vào 0h00 (nửa đêm) và 12h00 (trưa).

## 2. Các bước thiết lập cho Script Backup MariaDB

Giả sử file script của bạn đang nằm ở đường dẫn: `/sysadmin/script/mariadb_slave_backup.sh`

### Bước 1: Cấp quyền thực thi cho script (Nếu chưa làm)
Trước khi cron có thể chạy được file, file đó phải có quyền thực thi. Bạn chạy lệnh sau trên terminal:
```bash
sudo chmod +x /sysadmin/script/mariadb_slave_backup.sh
```

### Bước 2: Mở trình soạn thảo Cronjob
Đăng nhập bằng tài khoản `root` (vì script này cần quyền root/mysql) và gõ lệnh:
```bash
crontab -e
```
*(Nếu đây là lần đầu tiên bạn chạy lệnh này, hệ thống có thể hỏi bạn muốn dùng trình soạn thảo nào. Khuyên dùng số `1` tương ứng với `nano` cho dễ sử dụng).*

### Bước 3: Thêm lịch chạy Backup
Cuộn xuống dưới cùng của file và thêm dòng sau vào. Ví dụ dưới đây sẽ hẹn giờ chạy backup vào **2h00 sáng mỗi ngày**:

```bash
0 2 * * * /sysadmin/script/mariadb_slave_backup.sh >/dev/null 2>&1
```

**Giải thích:**
* `0 2 * * *`: Hẹn giờ 2h00 sáng mỗi ngày.
* `/sysadmin/script/mariadb_slave_backup.sh`: Đường dẫn tuyệt đối trỏ tới file script của bạn. (Trong cronjob, luôn phải dùng đường dẫn tuyệt đối, không dùng `./`).
* `>/dev/null 2>&1`: Lệnh này báo cho hệ thống bỏ qua việc gửi email log rác của cronjob. Do script của chúng ta đã tự động ghi log cực kỳ chi tiết vào `/sysadmin/logs/mysql_backup_...log` rồi, nên ta không cần hệ thống cron sinh thêm log thừa nữa.

### Bước 4: Lưu và thoát
* Nếu bạn đang dùng `nano`: Nhấn `Ctrl + O` -> `Enter` để lưu file, sau đó nhấn `Ctrl + X` để thoát.
* Màn hình sẽ báo `crontab: installing new crontab` nghĩa là bạn đã cài đặt lịch thành công.

### Bước 5: Kiểm tra lại lịch đã tạo
Để xem lại toàn bộ các lịch cronjob đang có của user hiện tại, bạn dùng lệnh:
```bash
crontab -l
```

---

## 3. Theo dõi kết quả
Sau khi cài đặt xong, bạn không cần phải làm gì thêm. Cứ sau 2h00 sáng, bạn có thể kiểm tra xem script có hoạt động tốt không bằng cách:
1. Xem log sinh ra: `cat /sysadmin/logs/mysql_backup_*(ngày_hiện_tại).log`
2. Xem file backup đã được tạo trong ổ cứng chưa: `ls -lh /sysadmin/backup/mysql/`