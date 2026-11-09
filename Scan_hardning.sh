#!/bin/bash

# Lấy phiên bản hệ điều hành
OS_VERSION=$(awk -F= '/^VERSION_ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

echo "Phiên bản hệ điều hành: $OS_VERSION"

if [[ "$OS_VERSION" == "22.04" ]]; then
    echo "--- Kiểm tra dành cho Ubuntu 22.04 ---"
    echo "============================================================"
	echo "MUC KIEM TRA: 1.1.1.1 - Vo hieu hoa mount voi cramfs filesystems (Ubuntu)"

	# Lấy dòng cuối cùng trong kết quả modprobe
	#MODPROBE_RESULT_CRAMFS=$(modprobe --dry-run --verbose cramfs 2>/dev/null | tail -n1)
	MODPROBE_RESULT_CRAMFS=$(modprobe --dry-run --verbose cramfs 2>/dev/null | tail -n1 | xargs)
	# Kiểm tra: chỉ chấp nhận đúng "install /bin/false"
	if [[ "$MODPROBE_RESULT_CRAMFS" == "install /bin/false" ]]; then
		DAT_MODPROBE=true
	else
		DAT_MODPROBE=false
	fi

	# Kiểm tra cramfs không có trong kernel
	LSMOD_RESULT_CRAMFS=$(lsmod | grep -w cramfs)
	if [[ -z "$LSMOD_RESULT_CRAMFS" ]]; then
		DAT_LSMOD=true
	else
		DAT_LSMOD=false
	fi

	# Tổng kết
	if [[ "$DAT_MODPROBE" == true && "$DAT_LSMOD" == true ]]; then
		echo "KET LUAN: ✅ DAT"
	else
		echo "KET LUAN: ❌ KHONG DAT"
		echo "LY DO:"
		if [[ "$DAT_MODPROBE" != true ]]; then
			echo "- modprobe cramfs KHONG bi vo hieu hoa dung cach:"
			echo "  (dong cuoi tra ve: $MODPROBE_RESULT_CRAMFS)"
		fi
		if [[ "$DAT_LSMOD" != true ]]; then
			echo "- Module cramfs DANG tai vao kernel:"
			echo "  $LSMOD_RESULT_CRAMFS"
		fi
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.1.2 - Vo hieu hoa mount voi squashfs filesystems"

	# 1. Lấy tất cả dòng 'install squashfs ...' từ cấu hình modprobe
	INSTALL_LINES=$(modprobe --showconfig 2>/dev/null | grep -E '^\s*install\s+squashfs\b')

	# 2. Đánh giá nếu có đúng duy nhất dòng 'install squashfs /bin/false'
	if [[ $(echo "$INSTALL_LINES" | grep -c '^install squashfs /bin/false$') -eq 1 ]] && \
	   [[ $(echo "$INSTALL_LINES" | wc -l) -eq 1 ]]; then
		DAT_MODPROBE=true
	else
		DAT_MODPROBE=false
	fi

	# 3. Kiểm tra module squashfs có đang được tải vào kernel không
	LSMOD_RESULT_SQUASHFS=$(lsmod | grep -w squashfs)
	if [[ -z "$LSMOD_RESULT_SQUASHFS" ]]; then
		DAT_LSMOD=true
	else
		DAT_LSMOD=false
	fi

	# 4. Tổng kết kết quả
	if [[ "$DAT_MODPROBE" == true && "$DAT_LSMOD" == true ]]; then
		echo "KET LUAN: ✅ DAT"
	else
		echo "KET LUAN: ❌ KHONG DAT"
		echo "LY DO:"
		if [[ "$DAT_MODPROBE" != true ]]; then
			echo "- Cac dong 'install squashfs' KHONG hop le:"
			echo "$INSTALL_LINES"
		fi
		if [[ "$DAT_LSMOD" != true ]]; then
			echo "- Module squashfs DANG tai vao kernel:"
			echo "$LSMOD_RESULT_SQUASHFS"
		fi
	fi




	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.1.3 - Vo hieu hoa mount voi udf filesystems"

	echo "MUC KIEM TRA: 1.1.1.3 - Vo hieu hoa mount udf filesystem (Ubuntu 22.04)"

	# Kiểm tra các dòng 'install udf ...' trong toàn hệ thống
	INSTALL_LINES=$(modprobe --showconfig 2>/dev/null | grep -E '^\s*install\s+udf\b')

	# Đánh giá nếu chỉ có duy nhất dòng 'install udf /bin/false'
	if [[ $(echo "$INSTALL_LINES" | grep -c '^install udf /bin/false$') -eq 1 ]] && \
	   [[ $(echo "$INSTALL_LINES" | wc -l) -eq 1 ]]; then
		DAT_MODPROBE=true
	else
		DAT_MODPROBE=false
	fi

	# Kiểm tra module udf có đang nạp không
	LSMOD_RESULT_UDF=$(lsmod | grep -w udf)
	if [[ -z "$LSMOD_RESULT_UDF" ]]; then
		DAT_LSMOD=true
	else
		DAT_LSMOD=false
	fi

	# Tổng kết
	if [[ "$DAT_MODPROBE" == true && "$DAT_LSMOD" == true ]]; then
		echo "KET LUAN: ✅ DAT"
	else
		echo "KET LUAN: ❌ KHONG DAT"
		echo "LY DO:"
		if [[ "$DAT_MODPROBE" != true ]]; then
			echo "- Cac dong 'install udf' KHONG hop le:"
			echo "$INSTALL_LINES"
		fi
		if [[ "$DAT_LSMOD" != true ]]; then
			echo "- Module udf DANG tai vao kernel:"
			echo "$LSMOD_RESULT_UDF"
		fi
	fi



	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.2 - Dam bao /tmp duoc cau hinh va mount"

	FSTAB_TMP=$(grep -E '\s/tmp\s' /etc/fstab)
	MOUNT_TMP=$(mount | grep -E '\s/tmp\s')

	if [[ -n "$FSTAB_TMP" && -n "$MOUNT_TMP" ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -z "$FSTAB_TMP" ]] && echo "- Chua cau hinh /tmp trong /etc/fstab"
		[[ -z "$MOUNT_TMP" ]] && echo "- Phan vung /tmp chua duoc mount"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.3 - Thiet lap tuy chon nodev cho /tmp"

	# Kiem tra trong /etc/fstab
	FSTAB_TMP_NODEV=$( grep -E '\s/tmp\s' /etc/fstab | grep nodev )

	# Kiem tra khi mount
	MOUNT_TMP_NODEV=$( mount | grep -E '\s/tmp\s' | grep nodev )

	if [[ -n "$FSTAB_TMP_NODEV" && -n "$MOUNT_TMP_NODEV" ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		if [[ -z "$FSTAB_TMP_NODEV" ]]; then
			echo "- /etc/fstab chua co tuy chon nodev cho /tmp"
		fi
		if [[ -z "$MOUNT_TMP_NODEV" ]]; then
			echo "- /tmp khong duoc mount voi tuy chon nodev"
		fi
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.4 - Thiet lap tuy chon nosuid cho /tmp"

	# Kiem tra trong /etc/fstab
	FSTAB_TMP_NOSUID=$( grep -E '\s/tmp\s' /etc/fstab | grep nosuid )

	# Kiem tra khi mount thuc te
	MOUNT_TMP_NOSUID=$( mount | grep -E '\s/tmp\s' | grep nosuid )

	if [[ -n "$FSTAB_TMP_NOSUID" && -n "$MOUNT_TMP_NOSUID" ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		if [[ -z "$FSTAB_TMP_NOSUID" ]]; then
			echo "- /etc/fstab khong co tuy chon nosuid cho /tmp"
		fi
		if [[ -z "$MOUNT_TMP_NOSUID" ]]; then
			echo "- /tmp khong duoc mount voi tuy chon nosuid"
		fi
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.5 - Thiet lap tuy chon noexec cho /tmp"

	# Gan mac dinh la dat
	dat=1

	# Kiem tra trong /etc/fstab
	FSTAB_TMP_NOEXEC=$(grep -E '\s/tmp\s' /etc/fstab | grep noexec)
	if [[ -z "$FSTAB_TMP_NOEXEC" ]]; then
		dat=0
	fi

	# Kiem tra khi mount thuc te
	MOUNT_TMP_NOEXEC=$(mount | grep -E '\s/tmp\s' | grep noexec)
	if [[ -z "$MOUNT_TMP_NOEXEC" ]]; then
		dat=0
	fi

	# Dua ra ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		if [[ -z "$FSTAB_TMP_NOEXEC" ]]; then
			echo "- /etc/fstab khong co tuy chon noexec cho /tmp"
		fi
		if [[ -z "$MOUNT_TMP_NOEXEC" ]]; then
			echo "- /tmp khong duoc mount voi tuy chon noexec"
		fi
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.6 - Dam bao phan vung /dev/shm duoc cau hinh"
	dat=1
	# Kiểm tra /dev/shm được mount hay không
	findmnt -n /dev/shm > /dev/null
	if [[ $? -ne 0 ]]; then
		dat=0
	fi

	# Kiểm tra có khai báo /dev/shm trong /etc/fstab hay không
	grep -qE '\s/dev/shm\s' /etc/fstab
	if [[ $? -ne 0 ]]; then
		dat=0
	fi

	# Đưa ra kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		if ! findmnt -n /dev/shm > /dev/null; then
			echo "- /dev/shm chua duoc mount tren he thong"
		fi
		if ! grep -qE '\s/dev/shm\s' /etc/fstab; then
			echo "- /etc/fstab khong co khai bao phan vung /dev/shm"
		fi
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.7 - Thiet lap tuy chon nodev cho /dev/shm"

	dat=1

	# Kiểm tra nodev trong /etc/fstab
	FSTAB_SHM_NODEV=$(grep -E '\s/dev/shm\s' /etc/fstab | grep nodev)
	if [[ -z "$FSTAB_SHM_NODEV" ]]; then
		dat=0
		reason1="- /etc/fstab khong co tuy chon nodev cho /dev/shm"
	fi

	# Kiểm tra mount với nodev
	MOUNT_SHM_NODEV=$(findmnt -no OPTIONS /dev/shm | grep nodev)
	if [[ -z "$MOUNT_SHM_NODEV" ]]; then
		dat=0
		reason2="- /dev/shm khong duoc mount voi tuy chon nodev"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.8 - Thiet lap tuy chon nosuid cho /dev/shm"

	dat=1

	# Kiểm tra nosuid trong /etc/fstab
	FSTAB_SHM_NOSUID=$(grep -E '\s/dev/shm\s' /etc/fstab | grep nosuid)
	if [[ -z "$FSTAB_SHM_NOSUID" ]]; then
		dat=0
		reason1="- /etc/fstab khong co tuy chon nosuid cho /dev/shm"
	fi

	# Kiểm tra mount với nosuid
	MOUNT_SHM_NOSUID=$(findmnt -no OPTIONS /dev/shm | grep nosuid)
	if [[ -z "$MOUNT_SHM_NOSUID" ]]; then
		dat=0
		reason2="- /dev/shm khong duoc mount voi tuy chon nosuid"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.9 - Thiet lap tuy chon noexec cho /dev/shm"

	dat=1

	# Kiểm tra noexec trong /etc/fstab
	FSTAB_SHM_NOEXEC=$(grep -E '\s/dev/shm\s' /etc/fstab | grep noexec)
	if [[ -z "$FSTAB_SHM_NOEXEC" ]]; then
		dat=0
		reason1="- /etc/fstab khong co tuy chon noexec cho /dev/shm"
	fi

	# Kiểm tra mount với noexec
	MOUNT_SHM_NOEXEC=$(findmnt -no OPTIONS /dev/shm | grep noexec)
	if [[ -z "$MOUNT_SHM_NOEXEC" ]]; then
		dat=0
		reason2="- /dev/shm khong duoc mount voi tuy chon noexec"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.10 - Dam bao phan vung /var duoc cau hinh"

	dat=1

	# Kiểm tra trong /etc/fstab
	if ! grep -qE '\s/var\s' /etc/fstab; then
		dat=0
		reason1="- /etc/fstab khong co cau hinh cho /var"
	fi

	# Kiểm tra mount thực tế
	if [[ -z $(findmnt -no SOURCE /var 2>/dev/null) ]]; then
		dat=0
		reason2="- /var khong duoc mount rieng biet hoac khong ton tai"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.11 - Thiet lap bind /var/tmp vao /tmp"

	dat=1

	# Kiểm tra cấu hình bind mount trong /etc/fstab
	if grep -Eq '^\s*(/tmp\s+/var/tmp|/var/tmp\s+/tmp)\s+none\s+bind' /etc/fstab; then
		:
	else
		dat=0
		reason1="- /etc/fstab chua duoc cau hinh bind /var/tmp vao /tmp"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi

	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.12 - Tao partition rieng cho /var/log"

	dat=1

	# Kiểm tra cấu hình trong /etc/fstab
	FSTAB_LOG=$(grep -E '^\s*[^#]+\s+/var/log\s' /etc/fstab)
	if [[ -z "$FSTAB_LOG" ]]; then
		dat=0
		reason1="- /etc/fstab chua duoc cau hinh partition rieng cho /var/log"
	fi

	# Kiểm tra mount thực tế
	MOUNT_LOG=$(findmnt -n /var/log)
	if [[ -z "$MOUNT_LOG" ]]; then
		dat=0
		reason2="- /var/log chua duoc mount rieng"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.13 - Tao partition rieng cho /var/log/audit"

	# Biến kiểm tra
	dat=1

	# Kiểm tra trong /etc/fstab
	FSTAB_AUDIT=$(grep -E '\s/var/log/audit\s' /etc/fstab)
	if [[ -z "$FSTAB_AUDIT" ]]; then
		dat=0
		reason1="- /etc/fstab chua duoc cau hinh partition rieng cho /var/log/audit"
	fi

	# Kiểm tra trạng thái mount thực tế
	MOUNT_AUDIT=$(findmnt -n /var/log/audit)
	if [[ -z "$MOUNT_AUDIT" ]]; then
		dat=0
		reason2="- /var/log/audit chua duoc mount rieng"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.14 - Tao partition rieng cho /home"

	dat=1

	# Kiểm tra trong /etc/fstab
	FSTAB_HOME=$(grep -E '\s/home\s' /etc/fstab)
	if [[ -z "$FSTAB_HOME" ]]; then
		dat=0
		reason1="- /etc/fstab chua duoc cau hinh partition rieng cho /home"
	fi

	# Kiểm tra trạng thái mount thực tế
	MOUNT_HOME=$(findmnt -n /home)
	if [[ -z "$MOUNT_HOME" ]]; then
		dat=0
		reason2="- /home chua duoc mount rieng"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.15 - Thiet lap tuy chon nodev cho /home"

	dat=1

	# Kiểm tra nodev trong /etc/fstab
	FSTAB_NODEV=$(grep -E '\s/home\s' /etc/fstab | grep nodev)
	if [[ -z "$FSTAB_NODEV" ]]; then
		dat=0
		reason1="- /etc/fstab chua duoc cau hinh tuy chon nodev cho /home"
	fi

	# Kiểm tra mount hiện tại có nodev không
	MOUNT_NODEV=$(findmnt -n /home | grep nodev)
	if [[ -z "$MOUNT_NODEV" ]]; then
		dat=0
		reason2="- Phan vung /home hien tai chua duoc mount voi tuy chon nodev"
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO:"
		[[ -n "$reason1" ]] && echo "$reason1"
		[[ -n "$reason2" ]] && echo "$reason2"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.1.16 - Thiet lap sticky bit tren cac thu muc world-writable"

	dat=1

	# Duyệt qua các phân vùng hệ thống tệp cục bộ và kiểm tra các thư mục có quyền world-writable nhưng chưa có sticky bit
	df --local -P | awk 'NR!=1 {print $6}' | xargs -I '{}' \
	find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null > /tmp/sticky_check_result

	# Kiểm tra kết quả
	if [[ -s /tmp/sticky_check_result ]]; then
		dat=0
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Ton tai cac thu muc world-writable chua duoc gan sticky bit."
	fi

	# Xóa file tạm
	rm -f /tmp/sticky_check_result
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.2.1 - Cai dat AIDE"

	dat=1

	# Kiểm tra cài đặt AIDE trên Ubuntu (bằng apt)
	AIDE_CHECK=$(dpkg -l | grep aide)
	if [[ -z "$AIDE_CHECK" ]]; then
		dat=0
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: He thong chua cai goi AIDE."
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.2.2 - Lap lich kiem tra dinh ky filesystem voi AIDE"

	dat=1

	# Kiểm tra cron của người dùng hiện tại
	CRON_USER=$(crontab -l 2>/dev/null | grep -i aide)
	[[ -z "$CRON_USER" ]] && dat=0

	# Kiểm tra cron trong /etc/cron.*
	CRON_ETC=$(grep -i aide /etc/cron.*/* 2>/dev/null)
	[[ -z "$CRON_ETC" ]] && dat=0

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Chua cau hinh lich cron cho viec kiem tra AIDE dinh ky."
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.3.1 - Gioi han coredump"

	dat=1

	# Kiểm tra dòng '* hard core 0' trong /etc/security/limits.conf
	grep -q "^\* hard core 0" /etc/security/limits.conf || dat=0

	# Kiểm tra cấu hình sysctl fs.suid_dumpable = 0
	SYSCTL_VAL=$(sysctl -n fs.suid_dumpable 2>/dev/null)
	[[ "$SYSCTL_VAL" != "0" ]] && dat=0

	# Kiểm tra trạng thái coredump.service nếu tồn tại
	if systemctl list-unit-files 2>/dev/null | grep -q "^systemd-coredump@.service"; then
		# Trên Ubuntu thường là template service, kiểm tra trạng thái hoạt động thực tế
		if systemctl list-units --all | grep -q "systemd-coredump@"; then
			ACTIVE=$(systemctl is-enabled systemd-coredump@* 2>/dev/null | uniq)
			[[ "$ACTIVE" != "disabled" ]] && dat=0
		fi
	elif systemctl list-unit-files 2>/dev/null | grep -q "coredump.service"; then
		systemctl is-enabled coredump.service 2>/dev/null | grep -q "disabled" || dat=0
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: He thong chua gioi han core dump dung cach"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.3.2 - Khoi dong vi tri vung nho ao tu dong"
	dat=1

	# Kiểm tra giá trị kernel.randomize_va_space
	RND_VAL=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
	[[ "$RND_VAL" != "2" ]] && dat=0

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Gia tri kernel.randomize_va_space khong phai bang 2"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 1.3.3 - Dam bao prelink khong duoc cai dat"
	dat=1

	# Kiểm tra gói prelink trên hệ thống (sử dụng dpkg cho Ubuntu)
	if dpkg -l | grep -qw prelink; then
		dat=0
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: He thong da cai goi prelink"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 1.4.1.1 - Dam bao SELINUX duoc cai dat"
	dat=1

	# Kiểm tra gói libselinux trên Ubuntu
	if ! dpkg -l | grep -qw libselinux1; then
		dat=0
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: He thong chua cai goi libselinux1"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.4.1.2 - Thiet lap chinh sach SELINUX"
	dat=1

	# Kiểm tra SELINUXTYPE trong file config (nếu tồn tại)
	/bin/grep -q "SELINUXTYPE=targeted" /etc/selinux/config 2>/dev/null || dat=0

	# Kiểm tra trạng thái loaded policy
	/usr/sbin/sestatus 2>/dev/null | grep -q "Loaded policy.*targeted" || dat=0

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: SELINUX chua duoc cau hinh voi target policy"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 1.4.1.3 - Dam bao SELINUX duoc bat o che do enforcing hoac permissive"
	dat=1

	# Kiểm tra trạng thái runtime của SELinux
	getenforce 2>/dev/null | grep -Eq "Enforcing|Permissive" || dat=0

	# Kiểm tra file cấu hình (nếu tồn tại)
	/bin/grep -Eq "^\s*SELINUX=(enforcing|permissive)" /etc/selinux/config 2>/dev/null || dat=0

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: SELINUX khong o che do enforcing hoac permissive hoac file cau hinh sai"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 1.4.1.4 - Cau hinh SELINUX o che do Enforcing"
	dat=1

	# Kiểm tra file config (nếu tồn tại)
	/bin/grep -iq "^SELINUX=enforcing" /etc/selinux/config 2>/dev/null || dat=0

	# Kiểm tra gói setroubleshoot có tồn tại không (trên Ubuntu)
	/usr/bin/dpkg -l | grep -qw setroubleshoot && dat=0

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: SELINUX khong o che do enforcing hoac da cai dat SETroubleshoot"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 1.4.1.5 - Xoa bo SETroubleshoot"
	dat=1

	# Kiểm tra setroubleshoot đã bị gỡ bỏ hay chưa
	/usr/bin/dpkg -l | grep -qw setroubleshoot && dat=0

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: He thong van con cai dat SETroubleshoot"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 1.4.1.6 - Xoa bo dich vu MSC Translation"
	# ----------- Kiem tra goi mcstrans ----------- #
	dat=1

	# Kiem tra mcstrans (Ubuntu khong dung rpm)
	dpkg -s mcstrans &> /dev/null && dat=0

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: mcstrans dang duoc cai dat tren he thong"
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 1.5.1 - Thiet lap banner canh bao cho cac dich vu dang nhap"
	# ----------- Kiem tra cac file banner: /etc/motd, /etc/issue, /etc/issue.net ----------- #
	dat=1

	# Kiem tra ton tai va quyen file /etc/motd
	if [[ ! -f /etc/motd || "$(stat -c %a /etc/motd)" != "644" ]]; then
		dat=0
	fi

	# Kiem tra ton tai va quyen file /etc/issue
	if [[ ! -f /etc/issue || "$(stat -c %a /etc/issue)" != "644" ]]; then
		dat=0
	fi

	# Kiem tra ton tai va quyen file /etc/issue.net
	if [[ ! -f /etc/issue.net || "$(stat -c %a /etc/issue.net)" != "644" ]]; then
		dat=0
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Mot hoac nhieu file banner khong ton tai hoac co quyen khong dung (yeu cau 644)"
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 1.5.2. Loai bo thong tin he dieu hanh khoi banner"
	# ----------- Kiem tra thong tin he dieu hanh trong banner ----------- #
	dat=1

	# Kiem tra cac file issue, motd, issue.net xem co chua thong tin OS
	egrep '(\\v|\\r|\\m|\\s)' /etc/issue > /dev/null && dat=0
	egrep '(\\v|\\r|\\m|\\s)' /etc/motd > /dev/null && dat=0
	egrep '(\\v|\\r|\\m|\\s)' /etc/issue.net > /dev/null && dat=0

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Banner con chua thong tin ve he dieu hanh (\\v, \\r, \\m, \\s)"
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 1.6. Dam bao updates, patches, security software duoc cai dat"
	# ----------- Kiem tra cac ban cap nhat he thong ----------- #
	dat=1

	# Kiem tra cap nhat (Ubuntu dung apt)
	

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Co ban cap nhat bi bo sot hoac khong the ket noi voi repository"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.1.1. Dam bao thoi gian duoc dong bo"
	# ----------- Kiem tra dich vu dong bo thoi gian ----------- #
	dat=0

	# Kiem tra chrony hoac ntp tren Ubuntu
	if dpkg -l | grep -q '^ii  chrony'; then
		dat=1
	elif dpkg -l | grep -q '^ii  ntp'; then
		dat=1
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Khong co dich vu dong bo thoi gian nao duoc cai dat (chrony hoac ntp)"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.1.2. Dam bao dich vu chrony duoc cau hinh"
	# ----------- Kiem tra cau hinh chrony.conf ----------- #
	dat=0

	# Kiem tra file cau hinh chrony
	if grep -Eq "^(server 10\.247\.251\.10|server 10\.247\.252\.250|server 10\.247\.255\.10)" /etc/chrony/chrony.conf 2>/dev/null; then
		dat=1
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: File /etc/chrony/chrony.conf chua duoc cau hinh ket noi den cac NTP server 10.247.251.10 / 10.247.252.250 / 10.247.255.10"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.1.3. Dam bao dich vu ntpd duoc cau hinh"
	# ----------- Kiem tra trang thai dich vu NTPD ----------- #
	dat=0

	if systemctl is-enabled ntp &>/dev/null; then
		if systemctl is-active ntp &>/dev/null; then
			dat=1
		fi
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Dich vu ntpd chua duoc cai dat, chua duoc kich hoat (enabled) hoac chua chay (active)"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.1.4. Go bo dich vu xinetd"
	# ----------- Kiem tra go bo xinetd ----------- #
	dat=1

	if dpkg -l | grep -q '^ii  xinetd'; then
		dat=0
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Goi xinetd van dang duoc cai dat tren he thong."
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.2. Go bo X Windows"

	# ----------- Kiem tra X Windows (xserver-xorg) ----------- #
	dat=1

	if dpkg -l | grep -q '^ii  xserver-xorg'; then
		dat=0
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Goi X Windows (xserver-xorg) van dang duoc cai dat tren he thong."
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.3. Vo hieu hoa Avahi server"

	# ----------- Kiem tra goi avahi ----------- #
	dat=1

	if dpkg -l | grep -q '^ii  avahi-daemon' || dpkg -l | grep -q '^ii  avahi-autoipd'; then
		dat=0
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: Avahi server (avahi-daemon hoac avahi-autoipd) van dang duoc cai dat tren he thong."
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.4. Vo hieu hoa print server CUPS"

	# ----------- Kiem tra cups ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  cups'; then
		dat=0
		reason="CUPS da duoc cai dat."
	fi

	CUPS_STATUS=$(systemctl is-enabled cups 2>/dev/null)
	if [[ "$CUPS_STATUS" == "enabled" ]]; then
		dat=0
		if [[ -n "$reason" ]]; then
			reason+=" Va dich vu CUPS dang bat."
		else
			reason="Dich vu CUPS dang bat."
		fi
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.5. Go bo DHCP server"

	# ----------- Kiem tra dhcp server ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  isc-dhcp-server'; then
		dat=0
		reason="DHCP server da duoc cai dat."
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.6. Go bo LDAP"

	# ----------- Kiểm tra openldap-servers (Ubuntu: slapd) ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  slapd'; then
		dat=0
		reason="slapd (LDAP server) da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.7. Go bo DNS Server"

	# ----------- Kiểm tra bind ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  bind9'; then
		dat=0
		reason="bind9 (DNS server) da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.8. Go bo FTP Server"

	# ----------- Kiểm tra vsftpd ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  vsftpd'; then
		dat=0
		reason="vsftpd (FTP server) da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.9. Go bo HTTP Server"

	# ----------- Kiểm tra apache2 (Ubuntu dùng apache2 thay vì httpd) ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  apache2'; then
		dat=0
		reason="apache2 (HTTP server) da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.10. Go bo dovecot (dich vu IMAP va POP3)"

	# ----------- Kiểm tra dovecot ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  dovecot-core'; then
		dat=0
		reason="dovecot da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.11. Go bo Samba"

	# ----------- Kiểm tra samba ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  samba'; then
		dat=0
		reason="Samba da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.12. Go bo HTTP Proxy server"

	# ----------- Kiểm tra squid ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  squid'; then
		dat=0
		reason="Squid da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.13. Go bo dich vu NIS server"

	# ----------- Kiểm tra ypserv (Ubuntu dung package `nis`) ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  nis'; then
		dat=0
		reason="nis (ypserv) da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.14. Go bo dich vu telnet server"

	# ----------- Kiểm tra telnet-server (Ubuntu dung package `telnetd`) ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  telnetd'; then
		dat=0
		reason="telnetd (telnet server) da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.15. Cau hinh MTA (Mail Transfer Agent) cho che do local-only"

	# ----------- Kiểm tra MTA có lắng nghe trên địa chỉ loopback (127.0.0.1) hay không ----------- #
	dat=1
	reason=""

	if ss -lntu | grep -E ':25\s' | grep -Ev '\s(127\.0\.0\.1|\[::1\]):25\s' &>/dev/null; then
		dat=0
		reason="MTA khong lang nghe tren dia chi loopback (127.0.0.1)."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.1.16. Vo hieu hoa NFS và RPC"

	# ----------- Kiểm tra dịch vụ rpcbind và nfs-common ----------- #
	dat=1
	reason=""

	if systemctl is-enabled rpcbind &>/dev/null; then
		dat=0
		reason="rpcbind dich vu dang bat."
	fi

	if systemctl is-enabled nfs-common &>/dev/null; then
		dat=0
		reason="nfs-common dich vu dang bat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.2.1. Go bo dich vu NIS client"

	# ----------- Kiểm tra nis (ypbind) ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  nis'; then
		dat=0
		reason="ypbind (nis) dang duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.2.2. Go bo dich vu rsh"

	# ----------- Kiểm tra rsh-client ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  rsh-client'; then
		dat=0
		reason="rsh-client dang duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 2.2.3. Go bo dich vu talk"

	# ----------- Kiểm tra talk ----------- #
	dat=1
	reason=""

	if dpkg -l | grep -q '^ii  talk'; then
		dat=0
		reason="talk da duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 2.2.4. Go bo Ldap client"

	dat=1
	reason=""

	# Kiểm tra gói ldap-utils (tương đương openldap-clients trên Ubuntu)
	if dpkg -l | grep -q ldap-utils; then
		dat=0
		reason="ldap-utils dang duoc cai dat."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.1.1. Vo hieu hoa IP Forwarding"

	dat=1
	reason=""

	ip_forward_value=$(sysctl net.ipv4.ip_forward)

	if [[ $ip_forward_value == *"= 0"* ]]; then
		dat=1
	else
		dat=0
		reason="net.ipv4.ip_forward khong duoc cai dat thanh 0."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hiện tại giá trị là: $ip_forward_value"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.1.2. Vo hieu hoa redirects goi tin gui"

	dat=1
	reason=""

	send_redirects_all=$(sysctl net.ipv4.conf.all.send_redirects)
	if [[ $send_redirects_all != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.all.send_redirects khong duoc dat thanh 0."
	fi

	send_redirects_default=$(sysctl net.ipv4.conf.default.send_redirects)
	if [[ $send_redirects_default != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.default.send_redirects khong duoc dat thanh 0."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.conf.all.send_redirects la: $send_redirects_all"
		echo "Hien tai gia tri net.ipv4.conf.default.send_redirects la: $send_redirects_default"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.1. Vo hieu hoa Source Routed Packet Acceptance"

	dat=1
	reason=""

	accept_source_route_all=$(sysctl net.ipv4.conf.all.accept_source_route)
	if [[ $accept_source_route_all != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.all.accept_source_route khong duoc dat thanh 0."
	fi

	accept_source_route_default=$(sysctl net.ipv4.conf.default.accept_source_route)
	if [[ $accept_source_route_default != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.default.accept_source_route khong duoc dat thanh 0."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.conf.all.accept_source_route la: $accept_source_route_all"
		echo "Hien tai gia tri net.ipv4.conf.default.accept_source_route la: $accept_source_route_default"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.2. Vo hieu hoa ICMP Redirect Acceptance"

	dat=1
	reason=""

	accept_redirects_all=$(sysctl net.ipv4.conf.all.accept_redirects)
	if [[ $accept_redirects_all != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.all.accept_redirects khong duoc dat thanh 0."
	fi

	accept_redirects_default=$(sysctl net.ipv4.conf.default.accept_redirects)
	if [[ $accept_redirects_default != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.default.accept_redirects khong duoc dat thanh 0."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.conf.all.accept_redirects la: $accept_redirects_all"
		echo "Hien tai gia tri net.ipv4.conf.default.accept_redirects la: $accept_redirects_default"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.3. Vo hieu hoa Secure ICMP Redirect Acceptance"

	dat=1
	reason=""

	secure_redirects_all=$(sysctl net.ipv4.conf.all.secure_redirects)
	if [[ $secure_redirects_all != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.all.secure_redirects khong duoc dat thanh 0."
	fi

	secure_redirects_default=$(sysctl net.ipv4.conf.default.secure_redirects)
	if [[ $secure_redirects_default != *"= 0"* ]]; then
		dat=0
		reason="net.ipv4.conf.default.secure_redirects khong duoc dat thanh 0."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.conf.all.secure_redirects la: $secure_redirects_all"
		echo "Hien tai gia tri net.ipv4.conf.default.secure_redirects la: $secure_redirects_default"
	fi
	

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.4. Log cac goi tin khong dang tin cay"

	dat=1
	reason=""

	# Kiểm tra giá trị của net.ipv4.conf.all.log_martians
	log_martians_all=$(sysctl net.ipv4.conf.all.log_martians 2>/dev/null)

	if [[ $log_martians_all == *"= 1"* ]]; then
		dat=1
	else
		dat=0
		reason="net.ipv4.conf.all.log_martians khong duoc dat thanh 1."
	fi

	# Kiểm tra giá trị của net.ipv4.conf.default.log_martians
	log_martians_default=$(sysctl net.ipv4.conf.default.log_martians 2>/dev/null)

	if [[ $log_martians_default != *"= 1"* ]]; then
		dat=0
		reason="net.ipv4.conf.default.log_martians khong duoc dat thanh 1."
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.conf.all.log_martians la: $log_martians_all"
		echo "Hien tai gia tri net.ipv4.conf.default.log_martians la: $log_martians_default"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.5. Kich hoat Ignore Broadcast Requests"

	dat=1
	reason=""

	icmp_echo_ignore_broadcasts=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null)

	if [[ $icmp_echo_ignore_broadcasts != *"= 1"* ]]; then
		dat=0
		reason="net.ipv4.icmp_echo_ignore_broadcasts khong duoc dat thanh 1."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.icmp_echo_ignore_broadcasts la: $icmp_echo_ignore_broadcasts"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.6. Kich hoat Bad Error Message Protection"

	dat=1
	reason=""

	icmp_ignore_bogus_error_responses=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses 2>/dev/null)

	if [[ $icmp_ignore_bogus_error_responses != *"= 1"* ]]; then
		dat=0
		reason="net.ipv4.icmp_ignore_bogus_error_responses khong duoc dat thanh 1."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.icmp_ignore_bogus_error_responses la: $icmp_ignore_bogus_error_responses"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.7. Kich hoat RFC- recommended Source Route Validation"

	dat=1
	reason=""

	rp_filter_all=$(sysctl net.ipv4.conf.all.rp_filter 2>/dev/null)

	if [[ $rp_filter_all != *"= 1"* ]]; then
		dat=0
		reason="net.ipv4.conf.all.rp_filter khong duoc dat thanh 1."
	fi

	rp_filter_default=$(sysctl net.ipv4.conf.default.rp_filter 2>/dev/null)

	if [[ $rp_filter_default != *"= 1"* ]]; then
		dat=0
		reason="net.ipv4.conf.default.rp_filter khong duoc dat thanh 1."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.conf.all.rp_filter la: $rp_filter_all"
		echo "Hien tai gia tri net.ipv4.conf.default.rp_filter la: $rp_filter_default"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.2.8. Kich hoat TCP SYN cookies"

	dat=1
	reason=""

	tcp_syncookies=$(sysctl net.ipv4.tcp_syncookies 2>/dev/null)

	if [[ $tcp_syncookies == *"= 1"* ]]; then
		dat=1
	else
		dat=0
		reason="net.ipv4.tcp_syncookies khong duoc bat (gia tri khac 1)."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
		echo "Hien tai gia tri net.ipv4.tcp_syncookies la: $tcp_syncookies"
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.1. Cai dat TCP Wrappers"

	dat=1
	reason=""

	tcp_wrappers_installed=$(dpkg -l | grep -E "^ii\s+libwrap")

	if [[ -n "$tcp_wrappers_installed" ]]; then
		:
	else
		dat=0
		reason="TCP Wrappers chua duoc cai dat."
	fi

	sshd_libwrap=$(ldd /usr/sbin/sshd 2>/dev/null | grep libwrap.so)

	if [[ -n "$sshd_libwrap" ]]; then
		:
	else
		dat=0
		reason="Dich vu SSH khong ho tro TCP Wrappers."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.2. Cau hinh file /etc/hosts.allow"

	dat=1
	reason=""

	if [[ -f /etc/hosts.allow ]]; then
		dat=1
	else
		dat=0
		reason="File /etc/hosts.allow khong ton tai."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi


	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.3. Xac thuc quyen file /etc/hosts.allow"

	dat=1
	reason=""

	if [[ -f /etc/hosts.allow ]]; then
		perms=$(stat -c "%a" /etc/hosts.allow)
		if [[ "$perms" == "644" ]]; then
			dat=1
		else
			dat=0
			reason="Quyen cua file /etc/hosts.allow khong dung (yeu cau 644)."
		fi
	else
		dat=0
		reason="File /etc/hosts.allow khong ton tai."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.4. Cau hinh file /etc/hosts.deny"

	dat=1
	reason=""

	# Kiểm tra file /etc/hosts.deny tồn tại
	if [[ -f /etc/hosts.deny ]]; then
		# Kiểm tra có dòng "ALL: ALL" (cho phép khoảng trắng sau dấu hai chấm)
		if grep -Eq '^\s*ALL\s*:\s*ALL\s*$' /etc/hosts.deny; then
			dat=1
		else
			dat=0
			reason="File /etc/hosts.deny khong chua dong 'ALL: ALL', co the khong tu choi ket noi tu cac host khong duoc dinh nghia trong /etc/hosts.allow."
		fi
	else
		dat=0
		reason="File /etc/hosts.deny khong ton tai."
	fi

	# Kết luận
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.5. Xac thuc quyen file /etc/hosts.deny"

	dat=1
	reason=""

	if [[ -f /etc/hosts.deny ]]; then
		file_permissions=$(stat -c "%A" /etc/hosts.deny)
		if [[ "$file_permissions" != "-rw-r--r--" ]]; then
			dat=0
			reason="Quyen cua file /etc/hosts.deny khong dung. Can co quyen '-rw-r--r--'."
		fi
	else
		dat=0
		reason="File /etc/hosts.deny khong ton tai."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.6 Enable Firewall"

	dat=1
	reason=""

	# Kiểm tra trạng thái UFW (Ubuntu thường dùng ufw)
	if command -v ufw &>/dev/null; then
		ufw_status=$(ufw status | head -n1)
		if [[ "$ufw_status" != "Status: active" ]]; then
			dat=0
			reason="Firewall ufw chua duoc bat."
		fi
	else
		dat=0
		reason="ufw khong duoc cai dat tren he thong."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.3.6.1 Dam bao rule iptables ton tai cho tat ca cac port dang mo"

	dat=1
	reason=""

	if ! command -v iptables &>/dev/null; then
		dat=0
		reason="iptables khong duoc cai dat tren he thong."
	else
		open_ports=$(ss -4tuln | awk '{print $5}' | grep -oE '[0-9]+$' | sort -u)

		for port in $open_ports; do
			rule_input=$(iptables -L INPUT -n | grep "dpt:$port")
			if [[ -z "$rule_input" ]]; then
				dat=0
				reason="Khong co quy tac tuong lua cho cong $port trong chuoi INPUT."
				break
			fi
		done
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.4.1. Cau hinh quyen cho file /etc/ssh/sshd_config"

	dat=1
	reason=""

	if [[ -f /etc/ssh/sshd_config ]]; then
		file_permissions=$(stat -c "%A" /etc/ssh/sshd_config)
		if [[ "$file_permissions" != "-rw-r--r--" ]]; then
			dat=0
			reason="Quyen cua tep /etc/ssh/sshd_config khong dung. Can phai la '-rw-r--r--'."
		fi

		# Kiểm tra audit rule nếu auditctl có trên hệ thống
		if command auditctl -v &>/dev/null; then
			audit_rule=$(auditctl -l)
			if [[ -z "$audit_rule" ]]; then
				dat=0
				reason="$reason Quy tac auditd chua duoc cau hinh cho /etc/ssh/sshd_config."
			fi
		else
			echo "Canh bao: auditctl khong duoc cai dat, khong the kiem tra audit rule."
		fi
	else
		dat=0
		reason="Tep /etc/ssh/sshd_config khong ton tai."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.4.2. Cau hinh giao thuc SSH su dung SSHv2"

	dat=1
	reason=""

	# Kiem tra Protocol trong tep /etc/ssh/sshd_config
	ssh_protocol=$(grep -i "^Protocol" /etc/ssh/sshd_config 2>/dev/null)

	if [[ -z "$ssh_protocol" ]]; then
		:
	elif [[ "$ssh_protocol" =~ "1" ]]; then
		dat=0
		reason="SSHv1 dang duoc su dung. Can thay doi sang SSHv2 de bao mat tot hon."
	elif [[ "$ssh_protocol" =~ "2" ]]; then
		:
	else
		dat=0
		reason="Phien ban SSH khong hop le trong tep cau hinh."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.4.3. Cau hinh LogLevel cho may chu SSH"

	dat=1
	reason=""

	log_level=$(grep -i "^LogLevel" /etc/ssh/sshd_config 2>/dev/null)

	if [[ -z "$log_level" ]]; then
		dat=0
		reason="Khong tim thay dong LogLevel trong tep /etc/ssh/sshd_config. Can them 'LogLevel INFO'."
	elif [[ "$log_level" =~ "INFO" ]]; then
		:
	else
		dat=0
		reason="LogLevel khong dung, hien tai la: $log_level. Can thay doi thanh 'LogLevel INFO'."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.4.4. Cau hinh vo hieu hoa X11 Forwarding cho may chu SSH"

	dat=1
	reason=""

	X11_SETTING=$(grep -i "^X11Forwarding" /etc/ssh/sshd_config 2>/dev/null)

	if [[ -z "$X11_SETTING" ]]; then
		dat=0
		reason="Khong tim thay dong X11Forwarding trong /etc/ssh/sshd_config. Mac dinh co the la YES."
	elif [[ "$X11_SETTING" =~ [Yy][Ee][Ss] ]]; then
		dat=0
		reason="X11Forwarding dang duoc bat: $X11_SETTING."
	elif [[ "$X11_SETTING" =~ [Nn][Oo] ]]; then
		:
	else
		dat=0
		reason="Cau hinh X11Forwarding khong ro rang: $X11_SETTING."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.4.5. Set SSH MaxAuthTries to 4 or Less"

	dat=1
	reason=""

	MAX_TRIES_LINE=$(grep -i "^MaxAuthTries" /etc/ssh/sshd_config 2>/dev/null)

	if [[ -z "$MAX_TRIES_LINE" ]]; then
		dat=0
		reason="Khong tim thay dong MaxAuthTries trong /etc/ssh/sshd_config. Co the dang dung mac dinh (6)."
	elif [[ "$(echo "$MAX_TRIES_LINE" | awk '{print $2}')" -le 4 ]]; then
		:
	else
		dat=0
		reason="MaxAuthTries hien tai la $(echo "$MAX_TRIES_LINE" | awk '{print $2}'), vuot qua khuyen nghi. Khuyen nghi chinh sua lai thanh 'MaxAuthTries 4'."
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.4.6. Dam bao viec dang nhap root qua SSH bi vo hieu hoa"

	dat=1
	reason=""

	# Lay hostname va IP cho sshd -T (Ubuntu 20.04+ dung duoc)
	ROOT_HOSTNAME=$(hostname)
	ROOT_IP=$(getent hosts "$ROOT_HOSTNAME" | awk '{print $1}' | head -n1)

	# Kiem tra sshd -T co ho tro tren he thong hien tai
	if command -v sshd >/dev/null && sshd -T -C user=root -C host="$ROOT_HOSTNAME" -C addr="$ROOT_IP" 2>/dev/null | grep -q permitrootlogin; then
		PERMIT_OUTPUT=$(sshd -T -C user=root -C host="$ROOT_HOSTNAME" -C addr="$ROOT_IP" 2>/dev/null | grep permitrootlogin)
		if ! echo "$PERMIT_OUTPUT" | grep -qi "permitrootlogin no"; then
			dat=0
			reason="PermitRootLogin chua duoc cau hinh dung theo khuyen nghi (phai la 'no'). Ket qua hien tai: $PERMIT_OUTPUT. "
		fi
	else
		reason+="Khong the kiem tra bang sshd -T. "
	fi

	# Kiem tra file sshd_config truc tiep
	if grep -Ei '^\s*PermitRootLogin\s+yes' /etc/ssh/sshd_config >/dev/null; then
		dat=0
		reason+="Phat hien dong PermitRootLogin yes trong /etc/ssh/sshd_config. "
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.5.1.1. Cau hinh kich hoat rsyslog service"

	dat=1
	reason=""

	# Kiem tra dich vu rsyslog
	if ! systemctl is-enabled rsyslog &>/dev/null; then
		dat=0
		reason+="Dich vu rsyslog chua duoc bat (enabled). "
	fi

	if ! systemctl is-active rsyslog &>/dev/null; then
		dat=0
		reason+="Dich vu rsyslog khong chay (inactive). "
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.5.1.2. Phan quyen doi voi file log sinh ra tu rsyslog"
	dat=1
	reason=""
	FOUND_MAIN=""

	# Kiem tra trong rsyslog.conf
	#if grep -Eq "^\s*\$FileCreateMode" /etc/rsyslog.conf; then
	if grep -Eq '^\s*\$FileCreateMode' /etc/rsyslog.conf; then
	  LINE=$(grep -E '^\s*\$FileCreateMode' /etc/rsyslog.conf | tail -1)
	  VALUE=$(echo "$LINE" | awk '{print $2}')
	  FOUND_MAIN="$VALUE"
	else
	  reason+="Khong tim thay \$FileCreateMode trong /etc/rsyslog.conf. "
	fi

	# Danh gia ket qua
	if [[ -z "$FOUND_MAIN" ]]; then
	  dat=0
	  reason+="Khong co thiet lap \$FileCreateMode chinh. "
	else
	  [[ "$FOUND_MAIN" =~ ^0 ]] && DEC_MAIN=$((8#$FOUND_MAIN)) || DEC_MAIN=$FOUND_MAIN
	  if (( DEC_MAIN > 416 )); then
		  dat=0
		  reason+="Gia tri \$FileCreateMode trong rsyslog.conf khong dam bao an toan ($FOUND_MAIN). "
	  fi
	fi

	if [[ $dat -eq 1 ]]; then
	  echo "KET LUAN: DAT"
	else
	  echo "KET LUAN: KHONG DAT"
	  echo "LY DO: $reason"
	fi

	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.5.2.1. Dam bao Auditd duoc cai dat (tu dong hoa)"

	dat=1
	reason=""

	# Kiem tra auditd va lib audit da duoc cai dat tren Ubuntu
	if ! dpkg -s auditd &>/dev/null || ! dpkg -s libaudit1 &>/dev/null; then
		dat=0
		reason="Mot hoac ca hai goi auditd va libaudit1 chua duoc cai dat."
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.5.2.2. Dam bao dich vu auditd duoc kich hoat va dang chay (tu dong hoa)"

	dat=1
	reason=""

	# Kiem tra dich vu auditd co duoc bat (enabled)
	if ! systemctl is-enabled auditd &>/dev/null; then
		dat=0
		reason+="Dich vu auditd chua duoc bat (enabled). "
	fi

	# Kiem tra dich vu auditd co dang chay (active)
	if ! systemctl is-active auditd &>/dev/null; then
		dat=0
		reason+="Dich vu auditd khong hoat dong (active)."
	fi

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.6.1.1. Cau hinh dieu kien tao mat khau"

	dat=1
	reason=""
	PWQUALITY_FILE="/etc/security/pwquality.conf"

	# Kiem tra minlen
	minlen=$(grep -E '^\s*minlen\s*=' "$PWQUALITY_FILE" | awk -F= '{print $2}' | xargs)
	if [[ -z "$minlen" || "$minlen" -lt 14 ]]; then
		dat=0
		reason+="minlen=$minlen < 14. "
	fi

	# Kiem tra minclass
	minclass=$(grep -E '^\s*minclass\s*=' "$PWQUALITY_FILE" | awk -F= '{print $2}' | xargs)
	if [[ -z "$minclass" || "$minclass" -lt 4 ]]; then
		dat=0
		reason+="minclass=$minclass < 4. "
	fi

	# Kiem tra dcredit/ucredit/lcredit/ocredit phai = -1
	for var in dcredit ucredit lcredit ocredit; do
		value=$(grep -E "^\s*$var\s*=" "$PWQUALITY_FILE" | awk -F= '{print $2}' | xargs)
		if [[ "$value" != "-1" ]]; then
			dat=0
			reason+="$var=$value ≠ -1. "
		fi
	done

	# Ket luan
	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.6.1.2. Cau hinh khoa truy cap do nhieu lan nhap mat khau that bai"

	dat=1
	reason=""

	FILE="/etc/pam.d/common-auth"

	# Kiem tra pam_faillock preauth
	if ! grep -Eq '^\s*auth\s+required\s+pam_faillock\.so\s+preauth.*deny=5.*unlock_time=900' "$FILE"; then
		dat=0
		reason+="[${FILE}] thieu hoac sai pam_faillock preauth. "
	fi

	# Kiem tra pam_unix success=1 default=bad
	if ! grep -Eq '^\s*auth\s+\[success=1\s+default=bad\]\s+pam_unix\.so' "$FILE"; then
		dat=0
		reason+="[${FILE}] thieu hoac sai pam_unix success=1 default=bad. "
	fi

	# Kiem tra pam_faillock authfail
	if ! grep -Eq '^\s*auth\s+\[default=die\]\s+pam_faillock\.so\s+authfail.*deny=5.*unlock_time=900' "$FILE"; then
		dat=0
		reason+="[${FILE}] thieu hoac sai pam_faillock authfail. "
	fi

	# Kiem tra pam_faillock authsucc
	if ! grep -Eq '^\s*auth\s+sufficient\s+pam_faillock\.so\s+authsucc.*deny=5.*unlock_time=900' "$FILE"; then
		dat=0
		reason+="[${FILE}] thieu hoac sai pam_faillock authsucc. "
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.6.1.3. Gioi han viec su dung lai mat khau"

	dat=1
	reason=""

	FILE="/etc/pam.d/common-password"

	if ! grep -Eq '^\s*password\s+.*pam_unix\.so.*remember=5' "$FILE"; then
		dat=0
		reason+="[${FILE}] thieu hoac sai pam_unix.so remember=5. "
	fi

	if [[ ! -f /etc/security/opasswd ]]; then
		dat=0
		reason+="Tep /etc/security/opasswd khong ton tai hoac chua co mat khau cu duoc luu. "
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.6.1.4. Cau hinh thuat toan hash mat khau sang SHA-512"

	dat=1
	reason=""

	FILE="/etc/pam.d/common-password"

	if [[ -f "$FILE" ]]; then
		if ! grep -Pq '^\h*password\h+(sufficient|required|requisite)\h+pam_unix\.so\h+.*\bsha512\b' "$FILE"; then
			dat=0
			reason+="[${FILE}] thieu hoac sai cau hinh sha512. "
		fi
	else
		dat=0
		reason+="[${FILE}] khong ton tai. "
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	
	echo "============================================================"
	echo "MUC KIEM TRA: 3.7.1.1. Thiet lap ngay het han mat khau"

	dat=1
	reason=""

	max_days_login_defs=$(grep -E '^\s*PASS_MAX_DAYS\s+' /etc/login.defs | awk '{print $2}')
	if [[ "$max_days_login_defs" -le 90 ]]; then
		:
	else
		dat=0
		reason+="PASS_MAX_DAYS trong /etc/login.defs dang la $max_days_login_defs, yeu cau <= 90. "
	fi

	users=$(awk -F: '$7 ~ /(bash|sh)$/ {print $1}' /etc/passwd)

	for user in $users; do
		max_days=$(chage -l "$user" | grep "Maximum number of days between password change" | awk -F: '{print $2}' | xargs)
		if [[ "$max_days" != "" && "$max_days" -le 90 ]]; then
			:
		else
			dat=0
			reason+="Nguoi dung $user co PASS_MAX_DAYS = $max_days (yeu cau <= 90). "
		fi
	done

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.7.1.2. Thiet lap gioi han so ngay toi thieu thay doi mat khau"

	dat=1
	reason=""

	DEF_VALUE=$(grep ^PASS_MIN_DAYS /etc/login.defs | awk '{print $2}')
	if [ -z "$DEF_VALUE" ]; then
		dat=0
		reason+="PASS_MIN_DAYS khong duoc thiet lap trong /etc/login.defs. "
	elif [ "$DEF_VALUE" -lt 7 ]; then
		dat=0
		reason+="PASS_MIN_DAYS = $DEF_VALUE trong /etc/login.defs (yeu cau >= 7). "
	fi

	getent passwd | awk -F: '$7 ~ /\/(bash|zsh|sh)$/ {print $1}' | while read USER; do
		MIN_DAYS=$(chage -l "$USER" | grep "Minimum number of days between password change" | awk -F: '{print $2}' | xargs)
		if [[ "$MIN_DAYS" == "0" || -z "$MIN_DAYS" || "$MIN_DAYS" -lt 7 ]]; then
			dat=0
			reason+="Nguoi dung $USER co PASS_MIN_DAYS = $MIN_DAYS (yeu cau >= 7). "
		fi
	done

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.7.1.3. Thiet lap so ngay canh bao het han mat khau"

	dat=1
	reason=""

	DEF_VALUE=$(grep ^PASS_WARN_AGE /etc/login.defs | awk '{print $2}')
	if [ -z "$DEF_VALUE" ]; then
		dat=0
		reason+="PASS_WARN_AGE khong duoc thiet lap trong /etc/login.defs. "
	elif [ "$DEF_VALUE" -lt 7 ]; then
		dat=0
		reason+="PASS_WARN_AGE = $DEF_VALUE trong /etc/login.defs (yeu cau >= 7). "
	fi

	getent passwd | awk -F: '$7 ~ /\/(bash|zsh|sh)$/ {print $1}' | while read USER; do
		WARN_DAYS=$(chage -l "$USER" | grep "Number of days of warning before password expires" | awk -F: '{print $2}' | xargs)

		if [[ -z "$WARN_DAYS" || "$WARN_DAYS" == "0" || "$WARN_DAYS" -lt 7 ]]; then
			dat=0
			reason+="Nguoi dung $USER: Canh bao truoc $WARN_DAYS ngay (nen >= 7). "
		fi
	done

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi

	echo "============================================================"
	echo "MUC KIEM TRA: 3.7.2. Khoa cac tai khoan khong hoat dong"

	dat=1
	reason=""

	INACTIVE=$(useradd -D | grep INACTIVE | awk -F= '{print $2}')
	if [ -z "$INACTIVE" ]; then
		dat=0
		reason+="Khong lay duoc INACTIVE mac dinh. "
	elif [ "$INACTIVE" -eq -1 ]; then
		dat=0
		reason+="INACTIVE = -1 (khong tu khoa tai khoan – KHONG AN TOAN). "
	elif [ "$INACTIVE" -lt 35 ]; then
		dat=0
		reason+="INACTIVE = $INACTIVE (nen ≥ 35). "
	fi

	if [[ $dat -eq 1 ]]; then
		echo "KET LUAN: DAT"
	else
		echo "KET LUAN: KHONG DAT"
		echo "LY DO: $reason"
	fi
	else
    echo "Phiên bản không được hỗ trợ bởi script này."
fi
