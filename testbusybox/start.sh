set -x
sudo umount ./myroot/
sudo mount -v -t aufs -obr=./updir/:./initdir:./image/ -o udba=none  none ./myroot/

sudo ip netns delete ns1

sudo ip netns add ns1

sudo ip link add type veth

sudo ip link set veth0 netns ns1
sudo ip netns exec ns1 ip link set veth0 up
sudo ip netns exec ns1 ip address add $1 dev veth0

sudo ip link set veth1 up
sudo ip address add $2 dev veth1

sudo ip netns exec ns1  chroot ./myroot /bin/mybash

