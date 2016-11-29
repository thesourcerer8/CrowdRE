# Just a simple query:
hdparm -g /dev/sda
# Read traffic:
dd if=/dev/sda1 |pv | dd of=/dev/null

