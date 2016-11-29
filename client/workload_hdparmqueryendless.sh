echo 1000 >/sys/block/sda/device/timeout
while true
do
hdparm -g /dev/sda 
done
