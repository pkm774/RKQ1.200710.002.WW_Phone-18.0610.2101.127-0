#!/system/vendor/bin/sh

# Parameter Definition
# $1: Caller

# Set Selinux
echo 1 > /sys/fs/selinux/log
sleep 1

mkdir /data/logcat_log
restorecon /data/everbootup
restorecon -FR /data/logcat_log

#workaround for asdf unlabeled
asdf_label=`ls -lZ /asdf | grep unlabeled`
if [ "$asdf_label" != "" ]; then
    restorecon -FR /asdf
    echo "[Debug] restorecon /asdf" > /proc/asusevtlog
fi

if [ ! -d /asdf/asdf_logcat ]; then
    mkdir /asdf/asdf_logcat
    restorecon -FR /asdf/asdf_logcat
    echo "[Debug] mkdir /asdf/asdf_logcat" > /proc/asusevtlog
fi

is_datalog_exist=`ls /data | grep logcat_log`
if test "$is_datalog_exist"; then
	chown system:system /data/logcat_log
	chmod 0777 /data/logcat_log
fi

startlog_flag=`getprop persist.vendor.asus.startlog`
version_type=`getprop ro.build.type`
check_factory_version=`grep -c androidboot.pre-ftm=1 /proc/cmdline`
is_sb=`grep -c SB=Y /proc/cmdline`
logcat_filenum=`getprop persist.vendor.asus.logcat.filenum`
is_clear_logcat_logs=`getprop vendor.asus.logcat.clear`
MAX_ROTATION_NUM=30
Caller=`getprop vendor.asus.check-data.caller`
charger_mode=`grep -c charger /proc/cmdline`

if test "$Caller" != ""; then
	setprop vendor.asus.check-data.caller ""
fi

for asusevtlog in /asdf/ASUSEvtlog*
do
	size=`stat -c%s $asusevtlog`
	if [ $size -gt 20971520  ]; then
		truncate -s 10485760 $asusevtlog
	fi
done

function start_logcat_services() {
    start logcat
    start logcat-radio
    start logcat-events
    start logcat-kernel
    stop logcat-asdf
    startlog_flag=`getprop persist.vendor.asus.startlog`
    check_status=`getprop init.svc.logcat`
    echo "[Debug] startlog flag: $startlog_flag, logcat services are $check_status." > /dev/kmsg
}

function stop_logcat_services() {
    stop logcat
    stop logcat-radio
    stop logcat-events
    stop logcat-kernel
    start logcat-asdf
    startlog_flag=`getprop persist.vendor.asus.startlog`
    check_status=`getprop init.svc.logcat-asdf`
    echo "[Debug] startlog flag: $startlog_flag, logcat-asdf is $check_status." > /dev/kmsg
}

######################################################################################
# For AsusLogTool logcat log rotation number setting
######################################################################################
if [ "$is_clear_logcat_logs" == "1" ]; then
	if [ "$logcat_filenum" != "3" ] && [ "$logcat_filenum" != "10" ] && [ "$logcat_filenum" != "20" ] && [ "$logcat_filenum" != "30" ]; then
		#if logcat_filenum get failed, sleep 1s and retry
		sleep 1
		logcat_filenum=`getprop persist.vendor.asus.logcat.filenum`

		if [ "$logcat_filenum" == "" ]; then
			logcat_filenum=20
		fi
	fi

	file_counter=$MAX_ROTATION_NUM
	while [ $file_counter -gt $logcat_filenum ]; do
		if [ $file_counter -lt 10 ]; then
			two_digit_file_counter=0$file_counter;
			
			if [ -e /data/logcat_log/logcat.txt.$two_digit_file_counter ]; then
				rm -f /data/logcat_log/logcat.txt.$two_digit_file_counter
			fi
		fi

		if [ -e /data/logcat_log/logcat.txt.$file_counter ]; then
			rm -f /data/logcat_log/logcat.txt.$file_counter
		fi
		
		file_counter=$(($file_counter-1))
	done

	setprop vendor.asus.logcat.clear "0"
fi

######################################################################################
# For original logcat service startlog
######################################################################################
if test -e /data/everbootup; then
	echo 1 > /data/everbootup
	restorecon /data/everbootup
else
	# Check debug property
	setprop persist.vendor.asus.ramdump 1
	setprop persist.vendor.asus.autosavelogmtp 0
	# For userdebug/eng build
	if  test "$version_type" = "eng"; then
		setprop persist.vendor.asus.kernelmessage 7
	elif test "$version_type" = "userdebug"; then
			if test "$check_factory_version" = "1"; then
				if test "$is_sb" = "1"; then
					setprop persist.vendor.asus.kernelmessage 0
				else
					setprop persist.vendor.asus.kernelmessage 7
				fi
				setprop persist.vendor.asus.enable_navbar 1
			else
				setprop persist.vendor.asus.kernelmessage 0
			fi
		setprop persist.vendor.sys.downloadmode.enable 1
	fi
	# Check debug service
	if [ "$version_type" == "userdebug" ] || [ "$version_type" == "eng" ]; then
		setprop persist.vendor.asus.startlog 1
		start_logcat_services
	fi

	if [ "$charger_mode" -ne 1 ]; then
		echo "[Debug] The file everbootup doesn't exist, data partition might be erased(factory reset)" > /proc/asusevtlog
		echo 0 > /data/everbootup
	fi
fi

# Check debug service
startlog_flag=`getprop persist.vendor.asus.startlog`
if [ "$startlog_flag" == 1 ]; then
	start_logcat_services
elif [ "$startlog_flag" == 0 ]; then
	echo 1 > /sys/fs/selinux/log
	stop_logcat_services
	logcat_status=`getprop init.svc.logcat-asdf`
	echo "init.svc.logcat-asdf = $logcat_status"
fi

# Start logcat-asdf by cmdline start_logcat_asdf
start_logcat_asdf=`grep -c start_logcat_asdf /proc/cmdline`
if [ "$start_logcat_asdf" == "1" ]; then
    echo "start_logcat_asdf = $start_logcat_asdf"
    stop_logcat_services
fi

# Set Selinux
startlog_flag=`getprop persist.vendor.asus.startlog`
install_logtool=`pm list packages com.asus.logtool`
mupload_enable=`getprop persist.vendor.asus.mupload.enable`
if [ "$mupload_enable" == 1 ] || [ -n "$install_logtool" ]; then
	echo "[Debug] $install_logtool, mupload_enable:$mupload_enable" > /dev/kmsg
	exit
elif [ "$startlog_flag" == 0 ]; then
	# check check_last service done
	sleep 1
	timeout=0
	while [ `getprop init.svc.check_last` -eq "running" ]; do
		timeout=$(($timeout+1))
		sleep 0.5
		check_last=`getprop init.svc.check_last`
		echo "[Debug] Check init.svc.check_last = $check_last ($timeout)"
		if [ $timeout == 10 ]; then
			echo "[Debug] $check_last check_last timeout & set selinux ($timeout)!!" > /dev/kmsg
			exit
		fi
	done
	echo 0 > /sys/fs/selinux/log
else
	echo 1 > /sys/fs/selinux/log
fi
