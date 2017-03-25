set -x

dev1=ns1_bridge_veth
dev2=ns2_bridge_veth

sudo ip link set dev mybr down
sudo brctl delbr mybr
sudo brctl addbr mybr

sudo ip link set dev $dev1 up
sudo ip link set dev $dev2 up
sudo ip link set dev mybr up
sudo brctl addif mybr $dev1
sudo brctl addif mybr $dev2

sudo route add -net 10.10.0.0 netmask 255.255.0.0 dev mybr

