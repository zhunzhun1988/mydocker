TARGETS = hostname.sh mountkernfs.sh mountdevsubfs.sh procps hwclock.sh checkroot.sh urandom checkroot-bootclean.sh bootmisc.sh mountnfs.sh mountall-bootclean.sh mountall.sh mountnfs-bootclean.sh checkfs.sh
INTERACTIVE = checkroot.sh checkfs.sh
mountdevsubfs.sh: mountkernfs.sh
procps: mountkernfs.sh
hwclock.sh: mountdevsubfs.sh
checkroot.sh: hwclock.sh mountdevsubfs.sh hostname.sh
urandom: hwclock.sh
checkroot-bootclean.sh: checkroot.sh
bootmisc.sh: checkroot-bootclean.sh mountall-bootclean.sh mountnfs-bootclean.sh
mountall-bootclean.sh: mountall.sh
mountall.sh: checkfs.sh checkroot-bootclean.sh
mountnfs-bootclean.sh: mountnfs.sh
checkfs.sh: checkroot.sh
