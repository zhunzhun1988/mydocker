set -x
sudo brctl delif br $1
sudo brctl delif br $2
sudo ip link set dev br down
sudo  brctl delbr br

sudo  brctl addbr br
sudo  ip link set dev br up
sudo ip link set dev $1 up
sudo ip link set dev $2 up
sudo  brctl addif br $1
sudo  brctl addif br $2
