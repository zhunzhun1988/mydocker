#/bin/bash

sudo brctl addbr mydocker
sudo ip link set mydocker up
sudo ip address add 10.11.1.1 dev mydocker
sudo ip netns add ns1
sudo ip link add type veth
sudo ip link set veth0 netns ns1
sudo ip netns exec ns1 ip address add 10.11.1.2 dev veth0
sudo ip netns exec ns1 ip link set dev veth0 name eth0
sudo ip netns exec ns1 ip link set dev eth0 up
sudo ip netns exec ns1 ip link set lo up
sudo ip link set dev veth1 name machine1
sudo ip link set dev machine1 up
sudo brctl addif mydocker machine1
