#!/system/bin/sh

setprop vendor.asus.setenforce 1
echo "[UpdateAttKey] setenforce: permissive" > /proc/asusevtlog
sleep 5
KmInstallKeybox /vendor/factory/key.xml auto true > /vendor/factory/AsusUpdateAttKey.log 2>&1
setprop vendor.asus.setenforce 0
echo "[UpdateAttKey] setenforce: enforcing" > /proc/asusevtlog
