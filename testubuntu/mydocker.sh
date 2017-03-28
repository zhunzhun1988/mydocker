#!/bin/sh 
#set -x
fGetMachineNum()
{
    for id in `seq 2 254`
    do 
        path=$curpath"/machines/rootmachine"$id
        if [ ! -d $path ]; then
           echo $id
           return
        fi
    done
    echo -1
}

fGetMachineIp()
{
    flannelNetIp=$(ip ad | grep flannel | grep -E [0-9]+\.[0-9]+\.[0-9]+\.[0-9] | awk '{for(i =1; i <=NF; i++){ if($i~/[0-9]\.[0-9]/) print $i}}' | cut -f 1-3 -d '.')
    echo $flannelNetIp"."$1
}

fStartEtcd()
{
    echo "++++++++++++++++starting etcd+++++++++++++++++++++++++"
    if [ -z "$(ps -fe|grep etcd  | grep -v grep)" ]; then
      sudo ./etcd/etcd --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 --advertise-client-urls=http://localhost:2379,http://localhost:4001 --listen-peer-urls=http://0.0.0.0:2380 --data-dir=/var/etcd/data 1>/dev/null 2>/dev/null &
      sleep 3 
      echo "++++++++++++++start etcd +++++++++++++++++++++++++++"
    else
      echo "++++++++++++++etcd is started+++++++++++++++++++++++"
    fi
}
fStartFlannel()
{
    echo "++++++++++++++++starting flannel+++++++++++++++++++++++++"
    if [ -z "$(ps -fe|grep flanneld  | grep -v grep)" ]; then
      sudo  ./flannel/flanneld  --etcd-endpoints=http://127.0.0.1:2379 --etcd-prefix=/coreos.com/network --ip-masq=true -logtostderr=false --log_dir=/var/log/flanneld 1>/dev/null 2>/dev/null &
      sleep 3
      echo "++++++++++++++start flannel +++++++++++++++++++++++++++"
    else
      echo "++++++++++++++flannel is started+++++++++++++++++++++++"
    fi
}

curpath=$(pwd)
bridge="mybr"
imagepath="$curpath/image"

_createmachine=""

createMyDocker() 
{
    _createmachine=""
    fStartEtcd
    fStartFlannel
    num=$(fGetMachineNum)
    if [ $num -lt 2 ]; then
       echo "get machine num err"
       return
    fi
    ip=$(fGetMachineIp $num)
    netip=$(echo $ip | cut -f 1-3 -d '.')".0"
    gwip=$(echo $ip | cut -f 1-3 -d '.')".1"
    netns="netns"$num
    rootpath=$curpath"/machines/rootmachine"$num
    runingpath=$curpath"/runningpath/machine"$num

    echo "##### it's the "$num" machine"
    echo "##### machine ip =" $ip
    echo "##### machine net ip=" $netip
    echo "##### machine net namespace =" $netns
    echo "##### machine image path =" $imagepath
    echo "##### machine running path=" $runingpath
    echo "##### machine root path =" $rootpath


    if [ ! -d "runingpath" ]; then
       mkdir -p $runingpath
    fi

    if [ ! -d "$rootpath" ]; then
       mkdir -p $rootpath
       sudo mount -v -t aufs -obr=$runingpath:$imagepath -o udba=none  none $rootpath
    fi

    sudo ip netns add $netns
    sudo ip link add type veth
    sudo ip link set veth0 netns $netns
    sudo ip netns exec $netns ip address add $ip dev veth0
    sudo ip netns exec $netns ip link set dev veth0 name eth0
    sudo ip link set dev veth1 name machine$num
    sudo ip link set dev machine$num up

    if [ -z "$( ip link | grep mybr:)" ] ; then
       sudo brctl addbr $bridge
    fi
    sudo ip link set dev $bridge up
    sudo ip address add $gwip dev $bridge
    sudo route add -net $netip netmask 255.255.255.0 dev $bridge


    echo "#create by startmachine.sh" > $runingpath/init.sh
    echo "ip link set dev lo up" >> $runingpath/init.sh
    echo "ip link set dev eth0 up" >> $runingpath/init.sh
    echo "mount -t proc proc /proc" >> $runingpath/init.sh
    echo "busybox route add -net $netip netmask 255.255.255.0 dev eth0" >> $runingpath/init.sh
    echo "busybox route add default gw $gwip" >> $runingpath/init.sh
    sudo chmod 777 $runingpath/init.sh
    _createmachine="rootmachine"$num
}

fStartMyDocker()
{
    id=$(echo $1 | tr -cd "[0-9]")
    netns="netns"$id
    rootpath=$curpath"/machines/rootmachine"$id

    sudo brctl addif $bridge machine$id
    sudo ip netns exec $netns  chroot $rootpath /bin/mybash2 mymachine$id
}

fHelp() 
{
    echo "Commands:"
    echo "  ps  Show running docker"
    echo "  run  Create and start a docker"
    echo "  start Start a created docker"
    echo "  stop   Stop a docker"
    echo "  clean  Stop all docker and clean the tmp fil"
}

fStopDocker()
{
   id=$(echo $1 | tr -cd "[0-9]")
   netns="netns"$id
   rootpath=$curpath"/machines/rootmachine"$id
   runingpath=$curpath"/runningpath/machine"$id
   
   pid=`ps -ef | grep  "00:00:00 /bin/mybash2" | grep mymachine$id  | awk -F' ' '{print $2}'`
  if [ ! -z "$pid" ]; then
      pid=$(ps -ef | grep -E "[0-9]+ $pid" |awk -F' ' '{print $2}')
      if [ ! -z "$pid" ]; then
         sudo kill -9 $pid
         sleep 1
      fi
   fi
   if [ ! -z "$(ip netns | grep $netns)" ]; then
       sudo ip netns delete $netns
       echo "++ delete netns" $netns
   fi
   if [ -d $rootpath ]; then
       sudo umount $rootpath
       sudo rm -rf $rootpath
       echo "++ delete machine"$id
   fi
   if [ -d $runingpath ]; then
       sudo rm -rf $runingpath
   fi  
}

fDockerPs()
{
   for m in $(ls ./machines)
   do
      if [ ! -z "$(ps -ef | grep mybash2 | grep $m)" ]; then
          echo $m "running"
      else
          echo $m "existed"
      fi
   done
}


fClean()
{
   for id in $(seq 1 255)
   do
      fStopDocker $id
   done
   sudo rm lastmachine 
}

if [ $# -lt 1 ]; then
   fHelp
elif [ "$1" = "run" ]; then
   createMyDocker
   if [ ! -z $_createmachine ]; then
       fStartMyDocker $_createmachine
   fi
elif [ "$1" = "create" ]; then
   createMyDocker
   if [ ! -z $_createmachine ]; then
      echo "docker $_createmachine is created success"
   fi
elif [ "$1" = "start" ]; then
   if [ $# -lt 2 ]; then
     echo "please input start docker name"
   else
     fStartMyDocker $2
   fi
elif [ "$1" = "stop" ]; then
   if [ $# -lt 2 ]; then
     echo "please input stop docker name"
   else
     fStopDocker $2
   fi
elif [ "$1" = "clean" ]; then
   fClean
elif [ "$1" = "ps" ]; then
   fDockerPs
else
   fHelp
fi

