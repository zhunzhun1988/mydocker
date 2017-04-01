#!/bin/bash 
#set -x

cgroupcpu=1000000
cgroupmem=""

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

fSetEtcd()
{
    config=$(./etcd/etcdctl get /coreos.com/network/config)
    if [ -z "$(echo $config | grep Network)" ]; then
        ./etcd/etcdctl set /coreos.com/network/config '{"Network": "10.9.0.0/16", "Backend": {"Type": "vxlan"}}'
    fi
}
fStartEtcd()
{
    if [ -z $etcd_server ]; then
            echo "++++++++++++++++starting etcd+++++++++++++++++++++++++"
        if [ -z "$(ps -fe|grep etcd  | grep -v grep)" ]; then
            sudo ./etcd/etcd --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 --advertise-client-urls=http://localhost:2379,http://localhost:4001 --listen-peer-urls=http://0.0.0.0:2380 --data-dir=/var/etcd/data 1>/dev/null 2>/dev/null &
             fSetEtcd
            sleep 3 
            echo "++++++++++++++++start    etcd+++++++++++++++++++++++++"
        else
            fSetEtcd
            echo "++++++++++++++++etcd is started+++++++++++++++++++++++"
        fi
    fi
}
fStartFlannel()
{
    server=127.0.0.1
    if [ ! -z $etcd_server ]; then
        server=$etcd_server
    fi
           echo "++++++++++++++++starting flannel++++++++++++++++++++++"
    if [ -z "$(ps -fe|grep flanneld  | grep -v grep)" ]; then
      sudo  ./flannel/flanneld  --etcd-endpoints=http://$server:2379 --etcd-prefix=/coreos.com/network --ip-masq=true -logtostderr=false --log_dir=/var/log/flanneld 1>/dev/null 2>/dev/null &
      sleep 3
           echo "++++++++++++++start flannel +++++++++++++++++++++++++"
    else
	  echo "+++++++++++++++flannel is started+++++++++++++++++++++"
    fi
}

curpath=$(pwd)
bridge="mybr"
infodir=$curpath"/runningpath/status"

_createmachine=""

createMyDocker() 
{       
    _createmachine=""
    if [ $# -lt 1 ]; then
       echo "please input which image to create"
       return
    fi
    imagename=$1
    imagepath=$curpath"/images/"$imagename"_image"
    if [ ! -d $imagepath ]; then
        echo "cann't find image of $1"
        return 
    fi   
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
    sudo brctl addif $bridge machine$num

    if [ -z "$(ip ad | grep $bridge | grep $gwip)" ]; then
        sudo ip address add $gwip dev $bridge
    fi

    if [ -z "$(route  | grep $netip)" ]; then
       sudo route add -net $netip netmask 255.255.255.0 dev $bridge
    fi

    #echo "#create by startmachine.sh" > $runingpath/init.sh 
    #echo "mount -t proc proc /proc" >> $runingpath/init.sh 
    #sudo chmod 777 $runingpath/init.sh
    sudo ip netns exec $netns ip link set dev lo up
    sudo ip netns exec $netns ip link set dev eth0 up
    sudo ip netns exec $netns route add -net $netip netmask 255.255.255.0 dev eth0
    sudo ip netns exec $netns route add default gw $gwip

    _createmachine="rootmachine"$num


    infopath=$infodir"/rootmachine"$num
    sudo mkdir $infodir 1>/dev/null 2>/dev/null
    sudo touch $infopath 1>/dev/null 2>/dev/null
    sudo chmod 777 $infopath
    echo "imagename:>$imagename" > $infopath
    echo "createtime:>$(date)" >> $infopath
    echo "cmd:>" >> $infopath
}

fGetCgroupPath()
{
   str=$(mount | grep cgroup | grep tmpfs)
   if [ ! -z "$str" ]; then
       path=$(echo $str |awk -F' ' '{print $3}')
       echo $path
   fi
}
fGetMemoryCgroup()
{
   rootPath=$(fGetCgroupPath)
   if [ -d $rootPath"/memory" ]; then
       echo $rootPath"/memory"
   fi
}
fGetCpuCgroup()
{
   rootPath=$(fGetCgroupPath)
   if [ -d $rootPath"/cpu" ]; then
       echo $rootPath"/cpu"
   fi    
}

fAddCpuLimit()
{
   if [ $# -lt 2 ]; then
      return
   fi
   mydockerpath=$(fGetCpuCgroup)"/mydocker"
   mymachinepath=$mydockerpath"/"$1
   cpulimit=$(($2 * 1000))
   if [ $cpulimit -lt 100 ]; then
      cpulimit=-1
   fi
   if [ ! -d $mydockerpath ]; then
     sudo mkdir $mydockerpath
   fi
   if [ ! -d $mymachinepath ]; then
     sudo mkdir $mymachinepath
   fi
   echo "1000000" > $mymachinepath"/cpu.cfs_period_us"
   echo $cpulimit > $mymachinepath"/cpu.cfs_quota_us"
   echo $mymachinepath
}

fAddMemoryLimit()
{
   if [ $# -lt 2 ]; then
      return
   fi
   mydockerpath=$(fGetMemoryCgroup)"/mydocker"
   mymachinepath=$mydockerpath"/"$1
   memorylimit=$2
   if [ -z $memorylimit ]; then
      return
   fi
   if [ ! -d $mydockerpath ]; then
     sudo mkdir $mydockerpath
   fi
   if [ ! -d $mymachinepath ]; then
     sudo mkdir $mymachinepath
   fi
   echo $memorylimit > $mymachinepath"/memory.limit_in_bytes"
   echo $memorylimit > $mymachinepath"/memory.soft_limit_in_bytes"
   echo $mymachinepath
}
fStartMyDocker()
{
    id=$(echo $1 | tr -cd "[0-9]")
    netns="netns"$id
    rootpath=$curpath"/machines/rootmachine"$id
    shift 1
    infopath=$infodir"/rootmachine"$id
    imagename=$(cat $infopath  | grep imagename | awk -F':>' '{print $2}')
    createtime=$(cat $infopath  | grep createtime | awk -F':>' '{print $2}')
    cmd=$*

    echo "imagename:>$imagename" > $infopath
    echo "createtime:>$createtime" >> $infopath
    echo "cmd:>$cmd" >> $infopath
     
    fAddCpuLimit "rootmachine"$id $cgroupcpu
    fAddMemoryLimit "rootmachine"$id $cgroupmem

    sudo cgexec -g cpu:"mydocker/rootmachine"$id ip netns exec $netns  chroot $rootpath /bin/mybash2 mymachine$id $*  
}

fHelp() 
{
    echo "Commands:"
    echo "  ps                                Show running docker"
    echo "  run imagename process             Create and start a docker"
    echo "  create imagename                  Create a docker"
    echo "  start machinename process         Start a created docker"
    echo "  stop  machinename                 Stop a docker"
    echo "  clean                             Stop all docker and clean the tmp fil"
}

fStopDocker()
{
   id=$(echo $1 | tr -cd "[0-9]")
   netns="netns"$id
   rootpath=$curpath"/machines/rootmachine"$id
   runingpath=$curpath"/runningpath/machine"$id
   mycpudockerpath=$(fGetCpuCgroup)"/mydocker"
   mycpumachinepath=$mydockerpath"/rootmachine"$1
   mymemdockerpath=$(fGetMemoryCgroup)"/mydocker"
   mymemmachinepath=$mymemdockerpath"/rootmachine"$1
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
   if [ -d $mycpumachinepath ]; then
       sudo rmdir $mycpumachinepath
   fi
   if [ -d $mymemmachinepath ]; then
       sudo rmdir $mymemmachinepath
   fi

}

fDockerPs()
{
   printf "MachineName\tImage\tCommand\t\tStatus\tCreateTime\n"
   for m in $(ls ./machines)
   do
      infopath=$infodir"/"$m
      imagename=$(cat $infopath  | grep imagename | awk -F':>' '{print $2}')
      createtime=$(cat $infopath  | grep createtime | awk -F':>' '{print $2}')
      cmd=$(cat $infopath  | grep cmd | awk -F':>' '{print $2}')

      if [ ! -z "$(ps -ef | grep mybash2 | grep $m)" ]; then
          status="running"
      else
          status="existed"
      fi
      printf "$m\t$imagename\t$cmd\t$status\t$createtime\n"
   done
}


fClean()
{
   for id in $(seq 1 10)
   do
      fStopDocker $id
   done
}

_argName=""
_argValue=""
fGetArg()
{
   _argName=""
   _argValue=""
   cmd=$1
   if [ ${cmd:0:1} = "-" ]; then
       pos=$(expr index $cmd '=')
       if [ $pos -gt 0 ]; then
           _argName=${cmd:1:$(($pos - 2))}
           _argValue=${cmd:$(($pos + 0))}
       fi
   fi
}

if [ ! `whoami` = "root" ]; then
   echo "please use root"
   exit
fi
cmd=$1
case $cmd in
     run)
    shift 1
    while true
    do
       fGetArg $1
       case $_argName in
          cpu)
            shift 1
            cgroupcpu=$_argValue
            ;;
          mem)
            shift 1
            cgroupmem=$_argValue
            ;;
          *)
           break
       esac
    done
    imagename=$1
    processname=$2
    if [ -z $imagename ]; then
       echo "please input run image"
       exit
    fi
    if [ -z $processname ]; then
       echo "please input which process to run"
       exit
    fi
    createMyDocker $imagename
    if [ ! -z $_createmachine ]; then
          shift 1
          fStartMyDocker $_createmachine $*
    fi
    ;;
  create)
    shift 1
    imagename=$1
    if [ -z $imagename ]; then
       echo "please input create image"
       return
    fi
    createMyDocker $imagename
    if [ ! -z $_createmachine ]; then
       echo "docker $_createmachine is created success"
    fi
    ;;
  start)
    shift 1
    while true
    do
       fGetArg $1
       case $_argName in
          cpu)
            shift 1
            cgroupcpu=$_argValue
            ;;
          mem)
            shift 1
            cgroupmem=$_argValue
            ;;
          *)
           break
       esac
    done
    machinename=$1
    processname=$2
    if [ -z $machinename ]; then
       echo "please input start machine name"
       return
    fi
    if [ -z $processname ]; then
       echo "please input start process name"
       return
    fi
    fStartMyDocker $*
    ;;
  stop)
    shift 1
    machinename=$1
    if [ -z $machinename ]; then
       echo "please input stop docker name"
       return
    fi
    fStopDocker $machinename
    ;;
 clean)
    fClean
    ;;
   ps)
    fDockerPs
    ;;
   *)
    fHelp
esac
