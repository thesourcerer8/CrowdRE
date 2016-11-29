echo 1000 >/sys/block/sda/device/timeout
while true
do
#dd if=/dev/sda of=/dev/null count=1 skip=1251255 #1317b7
dd if=/dev/sda of=/dev/null count=1 skip=4235125 #409F75
done
touch done
sleep 1
