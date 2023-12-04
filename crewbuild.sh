#!/bin/bash
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
  SESSION_TYPE=remote/ssh
elif pstree -p | egrep --quiet --extended-regexp ".*sshd.*\($$\)"; then
  SESSION_TYPE=remote/ssh
else
  case $(ps -o comm= -p $PPID) in
    sshd|*/sshd) SESSION_TYPE=remote/ssh;;
  esac
fi
if [ -z ${PAGER+x} ]; then
  echo "PAGER is not set."
else
  PAGER_PASSTHROUGH=-e
  PAGER_PASSTHROUGH+=" "
  PAGER_PASSTHROUGH+=CONTAINER_PAGER=${PAGER}
fi
X11+=" "
X11=-e
X11+=" "
X11+=DISPLAY=${DISPLAY:-:0.0}
X11+=" "
if ! [[ $SESSION_TYPE == remote/ssh ]] && [ -d /tmp/.X11-unix ]; then
  X11+=" -v /tmp/.X11-unix:/tmp/.X11-unix "
fi
if [ -f "$HOME"/.Xauthority ]; then
  X11+=--volume=$HOME/.Xauthority:/home/chronos/user/.Xauthority:rw
  X11+=" "
  X11+=--volume=$HOME/.Xauthority:/home/chronos/.Xauthority:rw
fi
docker pull --platform ${PLATFORM} ${REPOSITORY}/crewbuild:${name}.m${milestone}
docker pull tonistiigi/binfmt
docker run --privileged --rm tonistiigi/binfmt --install all
docker run --platform ${PLATFORM} --rm --net=host ${PAGER_PASSTHROUGH} ${X11} -e LOCALRC="${LOCALRC}" -it ${REPOSITORY}/crewbuild:${name}.m${milestone}
