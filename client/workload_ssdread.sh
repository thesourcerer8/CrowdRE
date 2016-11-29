echo 1000 >/sys/block/sda/device/timeout
rm sample
dd if=/dev/sda of=sample count=1 2>result 
touch done
sleep 1
diff expectedsector sample
