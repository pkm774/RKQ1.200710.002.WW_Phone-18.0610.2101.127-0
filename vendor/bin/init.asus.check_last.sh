#!/system/vendor/bin/sh

# Set selinux
echo 1 > /sys/fs/selinux/log
sleep 2

DownloadMode_flag=`getprop persist.vendor.sys.downloadmode.enable`
gsi_flag=`getprop ro.product.name`

echo "ASDF: Check LastShutdown log." > /proc/asusevtlog
echo get_asdf_log > /proc/asusdebug

##################################################################
# Set download mode
if test "$DownloadMode_flag" -eq 1; then
	echo 1 > /proc/QPSTInfo
	#echo 1 > /sys/module/msm_poweroff/parameters/download_mode
elif test "$DownloadMode_flag" -eq 0; then
	echo 0 > /proc/QPSTInfo
	#echo 0 > /sys/module/msm_poweroff/parameters/download_mode
fi

if test "$gsi_flag" = "aosp_arm64_ab"; then
	echo 1 > /sys/module/msm_poweroff/parameters/download_mode
	echo mini > /sys/kernel/dload/dload_mode
fi

if test "$gsi_flag" = "aosp_arm64"; then
	echo 1 > /sys/module/msm_poweroff/parameters/download_mode
	echo mini > /sys/kernel/dload/dload_mode
fi

# Check devcfg
if test "$DownloadMode_flag" -eq 1; then
	setprop persist.vendor.asus.checkdevcfg 1
fi

sleep 5
echo "[Debug] Check LastShutdown Log Done." > /dev/kmsg
##################################################################
# Set selinux
startlog_flag=`getprop persist.vendor.asus.startlog`
if test "$startlog_flag" -eq 0; then
	echo 0 > /sys/fs/selinux/log
else
	echo 1 > /sys/fs/selinux/log
fi
