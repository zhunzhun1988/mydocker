while true
do  
  busybox echo "this is $1" | busybox nc -l -p $2
done
