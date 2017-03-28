ip link set dev lo up
ip link set dev eth0 up
mount -t proc proc /proc
busybox route add -net 10.10.5.0 netmask 255.255.255.0 dev eth0
busybox route add default gw 10.10.5.1
