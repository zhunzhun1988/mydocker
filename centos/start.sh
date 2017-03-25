set -x
sudo umount ./myroot/
sudo mount -v -t aufs -obr=./updir/:./initdir:./image/ -o udba=none  none ./myroot/
sudo ip netns delete $1

sudo ip netns add $1

sudo ip link add type veth

sudo ip link set veth0 netns $1
#sudo ip netns exec $1 ip link set veth0 up
sudo ip netns exec $1 ip address add $2 dev veth0

sudo ip link set dev veth1 name $1_bridge_veth
sudo ip link set  $1_bridge_veth  up
#sudo ip address add $3 dev  $1_bridge_veth

sudo ip netns exec $1  chroot ./myroot /bin/bash

#sudo chroot ./myroot /bin/mybash
