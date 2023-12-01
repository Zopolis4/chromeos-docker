# DO NOT DELETE THIS LINE
# See /usr/local/etc/profile for further details
source /usr/local/etc/profile

# Put your stuff under this comment

echo "This is the .bashrc"
set -a
QEMU_CPU=max
[[ -n "$CREW_CACHE_DIR" ]] && CREW_CACHE_ENABLED=1
