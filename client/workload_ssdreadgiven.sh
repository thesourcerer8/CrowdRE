#!/bin/bash
echo 1000000 >/sys/block/sda/device/timeout
rm sample 2>/dev/null
rm workloadinfo 2>/dev/null
SECTOR=$1
ln -s "sector_$SECTOR" workloadinfo
dd if=/dev/sda of=sample count=1 bs=512 skip=$SECTOR 2>result 
rm workloadinfo 2>/dev/null
ln -s "`head -n 1 sample`" workloadinfo
touch done
sleep 1
#diff expectedsector sample
