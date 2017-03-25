ip link set dev lo up
ip link set dev eth0 up
mount -t proc proc /proc
busybox route add -net 10.10.0.0 netmask 255.255.0.0 dev eth0
