ip link set dev lo up
ip link set dev eth0 up
mount -t proc proc /proc
busybox route add -net 0.0.0.0 netmask 0.0.0.0 dev eth0
