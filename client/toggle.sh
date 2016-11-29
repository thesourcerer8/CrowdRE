echo Toggling $1
echo $1 >/sys/class/gpio/export
echo out >/sys/class/gpio/gpio$1/direction
while true
do
echo 1 >/sys/class/gpio/gpio$1/value
echo On
sleep 1
echo 0 >/sys/class/gpio/gpio$1/value
echo Off
sleep 1
done

