set -x
sudo ip netns del net0
sudo ip netns del net1
sudo ip netns del bridge
sudo ip link del net0-bridge
sudo ip link del net1-bridge
sudo ip link del bridge-net0
sudo ip link del bridge-net1
 
sudo ip netns add net0
sudo ip netns add net1
sudo ip netns add bridge
sudo ip link add type veth
sudo ip link set dev veth0 name net0-bridge netns net0
sudo ip link set dev veth1 name bridge-net0 netns bridge

sudo ip link add type veth
sudo ip link set dev veth0 name net1-bridge netns net1
sudo ip link set dev veth1 name bridge-net1 netns bridge

sudo ip netns exec bridge brctl addbr br
sudo ip netns exec bridge ip link set dev br up
sudo ip netns exec bridge ip link set dev bridge-net0 up
sudo ip netns exec bridge ip link set dev bridge-net1 up
sudo ip netns exec bridge brctl addif br bridge-net0
sudo ip netns exec bridge brctl addif br bridge-net1

sudo ip netns exec net0 ip link set dev net0-bridge up
sudo ip netns exec net0 ip address add 10.0.1.1/24 dev net0-bridge
sudo ip netns exec net1 ip link set dev net1-bridge up
sudo ip netns exec net1 ip address add 10.0.1.2/24 dev net1-bridge

