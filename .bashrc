# DO NOT DELETE THIS LINE
# See /usr/local/etc/profile for further details
source /usr/local/etc/profile

# Put your stuff under this comment

echo "This is the .bashrc"
set -a
QEMU_CPU=max
CFLAGS="-march=x86-64"
: "${LANG:=en_US.UTF-8}"
: "${LC_ALL:=en_US.UTF-8}"
