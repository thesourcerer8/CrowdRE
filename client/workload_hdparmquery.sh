echo "Expected:      = 30401/255/63, sectors = 488397168, start = 0" >expected
echo 1000 >/sys/block/sda/device/timeout
hdparm -g /dev/sda >result
touch done
sleep 1
cat result expected
