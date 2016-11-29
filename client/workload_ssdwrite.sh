echo 1000 >/sys/block/sda/device/timeout
dd if=expectedsector of=/dev/sda count=1 2>result 
touch done
sleep 1
