set -x
sudo umount ./myroot22/
sudo mount -v -t aufs -obr=./updir2/:./initdir2:./image/ -o udba=none  none ./myroot2/
sudo ip netns delete $1

sudo ip netns add $1

sudo ip link add type veth

sudo ip link set veth0 netns $1
sudo ip netns exec $1 ip address add $2 dev veth0
sudo ip netns exec $1 ip link set dev veth0 name eth0

sudo ip link set dev veth1 name $1_bridge_veth
sudo ip link set dev $1_bridge_veth  up

sudo ip netns exec $1  chroot ./myroot2 /bin/mybash2

