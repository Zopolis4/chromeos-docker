#!/bin/bash
# Copyright 2021-2023 Satadru Pramanik
# Copyright 2023 Maximilian Downey Twiss
# SPDX-License-Identifier: GPL-3.0-or-later
name="${1}"
milestone="${2}"
: "${outdir:=$(pwd)}"
: "${REPOSITORY:=satmandu}"
: "${PKG_CACHE:=$outdir/pkg_cache}"
echo "       name: ${name}"
echo "  milestone: ${milestone}"
echo " REPOSITORY: ${REPOSITORY}"
echo "output root: ${outdir}"
echo "  PKG_CACHE: ${PKG_CACHE}"

function abspath {
  echo $(cd "$1" && pwd)
}
countdown()
(
  IFS=:
  set -- $*
  secs=$(( ${1#0} * 3600 + ${2#0} * 60 + ${3#0} ))
  while [ $secs -gt 0 ]
  do
    sleep 1 &
    printf "\r%02d:%02d:%02d" $((secs/3600)) $(( (secs/60)%60)) $((secs%60))
    secs=$(( $secs - 1 ))
    wait
  done
  echo
)

setup_base () {
  url="$(jq -r .\""${name}"\"[\""Recovery Images"\"][\""${milestone}"\"] boards.json)"
  cached_image="$(echo ${url} | sed "s/https:\/\/dl.google.com\/dl\/edgedl\/chromeos\/recovery\/chromeos_//" | sed 's/_r.*//')"
  if [[ ! -f "${cached_image}.tar" ]] ; then
    echo "Cached image not found for ${cached_image}"

    # Download image
    curl --progress-bar --retry 3 -Lf "${url}" -o "${cached_image}".zip || ( echo "Download failed" && kill $$ )

    # Extract image

    # Extract the various layers of archives until we get to the root filesystem
    # 7zip does not currently support extracting nested archives in one command, or extracting from stdin
    7z x "${cached_image}".zip -so > "${cached_image}".bin
    7z x "${cached_image}".bin 2.ROOT-A.img
    7z x -snld 2.ROOT-A.img -o"${cached_image}"

    # Tar the unpacked filesystem for importing into docker
    (cd "${cached_image}" && tar -pcf ../"${cached_image}".tar .)

    # Clean up after ourselves
    rm -f "${cached_image}".zip "${cached_image}".bin 2.ROOT-A.img
    rm -rf "${cached_image}"
  else
    echo "Cached image found for ${cached_image}, skipping download."
  fi
}

get_arch () {
  user_arch="$(jq -r ."${name}"[\""User ABI"\"] boards.json)"
  if [[ "$user_arch" == "x86_64" ]]; then
    ARCH_LIB=lib64
    ARCH=x86_64
    DOCKER_PLATFORM=amd64
    PLATFORM="linux/amd64"
  elif [[ "$user_arch" == "arm" ]]; then
    ARCH=armv7l
    ARCH_LIB=lib
    DOCKER_PLATFORM=arm32v7
    PLATFORM="linux/arm/v7"
  elif [[ "$user_arch" == "x86" ]]; then
    ARCH=i686
    ARCH_LIB=lib
    DOCKER_PLATFORM=386
    PLATFORM="linux/386"
  fi
  CREW_KERNEL_VERSION="$(jq -r ."${name}"[\""Kernel Version"\"] boards.json)"
  CREW_LIB_PREFIX=/usr/local/$ARCH_LIB
}
import_to_Docker () {
  if ! docker image ls | grep "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}" ; then
    docker import "${cached_image}".tar --platform "${PLATFORM}" "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}"
  fi
}
build_dockerfile () {
  cd "${outdir}" || exit
  cat <<EOFFFFF > ./"${ARCH}"/.dockerignore
*image.bin* 
*.lz4 
pkg_cache/*
EOFFFFF
    cat <<EOFFFF > ./"${ARCH}"/Dockerfile
# syntax=docker/dockerfile:1.3-labs
ARG UID=1000
FROM ${REPOSITORY}/crewbase:${name}-${ARCH}.m${milestone} AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on \$BUILDPLATFORM, building for \$TARGETPLATFORM" 
#ENV LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$CREW_LIB_PREFIX
# Set githup repo information being synced from for install.
ENV REPO=chromebrew
ENV OWNER=chromebrew
ENV BRANCH=master
ENV CREW_KERNEL_VERSION=$CREW_KERNEL_VERSION
ENV ARCH=$ARCH
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/bin
ENV HOME=/home/chronos/user/
ENV LANG=en_US.UTF-8
ENV LC_all=en_US.UTF-8
ENV XML_CATALOG_FILES=/usr/local/etc/xml/catalog
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=bind,target=/input <<EOF1
passwd -d chronos
echo "chronos ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Defaults env_keep+=\"LOCALRC\"" >> /etc/sudoers
# Create /var/run/chrome - this is used by some X11 apps.
mkdir -p /var/run/chrome
chown chronos:chronos /var/run/chrome
tee -a /home/chronos/user/.profile <<TEEPROFILEEOF
set -a
CREW_TESTING_REPO=https://github.com/chromebrew/chromebrew.git
CREW_TESTING_BRANCH=master
CREW_TESTING=0
set +a
TEEPROFILEEOF
chown chronos:chronos /home/chronos/user/.profile
tee -a /home/chronos/user/.bashrc <<TEEBASHRCEOF
echo "This is the .bashrc"
set -a
QEMU_CPU=max
: "\\\${LANG:=en_US.UTF-8}"
: "\\\${LC_ALL:=en_US.UTF-8}"
[[ -d "/output/pkg_cache" ]] && CREW_CACHE_DIR=/output/pkg_cache
[[ -n "\\\$CREW_CACHE_DIR" ]] && CREW_CACHE_ENABLED=1
set +a
TEEBASHRCEOF
chown chronos:chronos /home/chronos/user/.bashrc
tee -a /bin/chromebrewstart <<CHROMEBREWSTARTEOF
#!/bin/bash
# Chromebrew container startup script.
# Author: Satadru Pramanik (satmandu) satadru at gmail dot com
CONTAINER_ARCH="\\\$(file /bin/bash | awk '{print \\\$7}' | sed 's/,//g')"
PASSTHROUGH_ARCH="\\\$(uname -m)"
if [ -n "\\\$LOCALRC" ]; then echo "LOCALRC is \\\$LOCALRC" ; fi
echo "CONTAINER_ARCH: \\\$CONTAINER_ARCH"
echo "PASSTHROUGH_ARCH: \\\$PASSTHROUGH_ARCH"
default_container_cmd="/usr/bin/sudo -i -u chronos"

case \\\$CONTAINER_ARCH in

  x86-64)
    exec \\\$default_container_cmd
    ;;

  Intel)
    SETARCH_ARCH=i686
    setarch_container_cmd="/usr/local/bin/setarch \\\${SETARCH_ARCH} sudo -i -u chronos"
    [[ "\\\${PASSTHROUGH_ARCH}" == "i686" ]] && exec \\\$default_container_cmd
    [[ "\\\${PASSTHROUGH_ARCH}" == "x86_64" ]] && exec \\\$setarch_container_cmd
    ;;

  ARM)
    SETARCH_ARCH=armv7l
    setarch_container_cmd="/usr/local/bin/setarch \\\${SETARCH_ARCH} sudo -i -u chronos"
    [[ "\\\${PASSTHROUGH_ARCH}" =~ ^(armv7l|armv8l)$ ]] && exec \\\$default_container_cmd
    [[ "\\\${PASSTHROUGH_ARCH}" == 'aarch64' ]] && exec \\\$setarch_container_cmd
    ;;

  *)
    echo "Chromebrew container startup script fallthrough option..."
    exec /bin/bash
    ;;
esac
CHROMEBREWSTARTEOF
chmod +x /bin/chromebrewstart
if [[ -f /input/install.sh.test ]]; then
  cp /input/install.sh.test /home/chronos/user/install.sh
  echo "Using local installer script install.sh.test!"
else
  curl -Ls https://github.com/\$OWNER/\$REPO/raw/\$BRANCH/install.sh -o /home/chronos/user/install.sh
fi 
chown chronos /usr/local
chown chronos /home/chronos/user/install.sh
chmod +x /home/chronos/user/install.sh
EOF1
# crew_profile_base isn't getting postinstall run on i686
SHELL ["/usr/bin/sudo", "-E", "-n", "BASH_ENV=/home/chronos/user/.bashrc", "-u", "chronos", "/bin/bash", "-c"]
RUN --mount=type=bind,target=/input <<EOF2
PATH=/usr/local/bin:/usr/local/sbin:\$PATH \
  CREW_CACHE_DIR=/input/pkg_cache \
  CREW_CACHE_ENABLED=1 \
  OWNER=\$OWNER \
  BRANCH=\$BRANCH \
  CREW_FORCE_INSTALL=1 \
  CREW_KERNEL_VERSION=\$CREW_KERNEL_VERSION \
  /bin/bash /home/chronos/user/install.sh
cd /usr/local/lib/crew/packages
echo "Disk Space used by initial install:"
du -ahx /usr/local | tail
echo "Packages installed but not in core_packages.txt:"
comm -13 <(cat ../tools/core_packages.txt| sort) <(crew -d list installed| sort)
LD_LIBRARY_PATH=$CREW_LIB_PREFIX:\$LD_LIBRARY_PATH \
  crew postinstall crew_profile_base
yes | LD_LIBRARY_PATH=$CREW_LIB_PREFIX:\$LD_LIBRARY_PATH \
  crew install util_linux psmisc
EOF2
# We can use setarch now that util_linux is installed.
SHELL ["/usr/bin/sudo", "-E", "-n", "BASH_ENV=/home/chronos/user/.bashrc", "-u", "chronos", "setarch", "$ARCH", "/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=bind,target=/input <<EOF3
yes | \
  LD_LIBRARY_PATH=$CREW_LIB_PREFIX:\$LD_LIBRARY_PATH \
  PATH=/usr/local/bin:/usr/local/sbin:\$PATH \
  CREW_CACHE_DIR=/input/pkg_cache \
  CREW_CACHE_ENABLED=1 \
  crew install buildessential || true
  echo -e "\necho \"This is the .bash_profile\"\n#Without this, env.d files do not get sourced.\nif [ -f ~/.bashrc ]; then . ~/.bashrc; fi\ncd /usr/local/lib/crew/packages\ncrew update\nif [ -n \"\\\$LOCALRC\" ]; then echo \"LOCALRC found!\"; . \"\\\$LOCALRC\"; fi" >> /home/chronos/user/.bash_profile
  if gem list -i "^rubocop\$" ; then
  echo 'Running gem update -N --system'
    gem update -N --system
  else
    echo 'Running  gem install -N rubocop --conservative'
    gem install -N rubocop --conservative
  fi
  if ! gem list -i "^concurrent-ruby\$" ; then
    echo 'Running gem install -N concurrent-ruby --conservative'
    gem install -N concurrent-ruby --conservative
  fi
EOF3
CMD /bin/chromebrewstart
EOFFFF
}
build_docker_image_with_docker_hub () {
  docker ps
  echo "Tag & Push starting in ..." && countdown "00:00:01"
  if ! docker pull "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}" ; then 
  docker tag "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}" "${REPOSITORY}"/crewbase:"${DOCKER_PLATFORM}"
  docker push "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}"
fi
}
make_cache_links () {
  mkdir -p ./"${ARCH}"/pkg_cache
  for i in $(cd pkg_cache && ls ./*"${ARCH}"*.*xz) 
  do
  ln -f pkg_cache/"$i" ./"${ARCH}"/pkg_cache/"$i" 2>/dev/null || ( [[ ! -f ./${ARCH}/pkg_cache/$i ]] && cp pkg_cache/"$i" ./"${ARCH}"/pkg_cache/"$i" )
  done
}
build_docker_image () {
  docker image ls
  dangling_images=$(docker images --filter "dangling=true" -q --no-trunc)
  [[ -n "$dangling_images" ]] && docker rmi -f $(docker images --filter "dangling=true" -q --no-trunc)
  docker pull tonistiigi/binfmt
  docker run --privileged --rm tonistiigi/binfmt --uninstall qemu-*
  docker run --privileged --rm tonistiigi/binfmt --install all
  docker buildx rm builder
  docker buildx create --name builder --driver docker-container --use --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10485760
  docker buildx inspect --bootstrap
  buildx_cmd="env PROGRESS_NO_TRUNC=1 docker buildx build \
  --no-cache \
  --push --platform ${PLATFORM} \
  --tag ${REPOSITORY}/crewbuild:${name}-${ARCH}.m${milestone} \
  --tag ${REPOSITORY}/crewbuild:m${milestone}-${ARCH} \
  --tag ${REPOSITORY}/crewbuild:${DOCKER_PLATFORM} \
  ./${ARCH}/"
  echo "$buildx_cmd"
  $buildx_cmd  || echo "Docker Build Error."
}
make_docker_image_script () {
  dockercmd="docker run --platform ${PLATFORM} --rm --net=host \${PAGER_PASSTHROUGH} \${X11} -e LOCALRC=\"\${LOCALRC}\" -v \$(pwd)/pkg_cache:/usr/local/tmp/packages -v \$(pwd):/output -h \$(hostname)-${ARCH} -it ${REPOSITORY}/crewbuild:${name}-${ARCH}.m${milestone}"
  [[ -f $(abspath "${outdir}")/crewbuild-${name}-${ARCH}.m${milestone}.sh ]] && rm $(abspath "${outdir}")/crewbuild-"${name}"-"${ARCH}".m"${milestone}".sh
  cat <<IMAGESCRIPTEOF > $(abspath "${outdir}")/crewbuild-"${name}"-"${ARCH}".m"${milestone}".sh
#!/bin/bash
if [ -n "\$SSH_CLIENT" ] || [ -n "\$SSH_TTY" ]; then
  SESSION_TYPE=remote/ssh
elif pstree -p | egrep --quiet --extended-regexp ".*sshd.*\(\$\$\)"; then
  SESSION_TYPE=remote/ssh
else
  case \$(ps -o comm= -p \$PPID) in
    sshd|*/sshd) SESSION_TYPE=remote/ssh;;
  esac
fi
if [ -z \${PAGER+x} ]; then 
  echo "PAGER is not set."
else 
  PAGER_PASSTHROUGH=-e
  PAGER_PASSTHROUGH+=" "
  PAGER_PASSTHROUGH+=CONTAINER_PAGER=\${PAGER}
fi
X11+=" "
X11=-e
X11+=" "
X11+=DISPLAY=\${DISPLAY:-:0.0}
X11+=" "
if ! [[ \$SESSION_TYPE == remote/ssh ]] && [ -d /tmp/.X11-unix ]; then
  X11+=" -v /tmp/.X11-unix:/tmp/.X11-unix "
fi
if [ -f "\$HOME"/.Xauthority ]; then
  X11+=--volume=\$HOME/.Xauthority:/home/chronos/user/.Xauthority:rw
  X11+=" "
  X11+=--volume=\$HOME/.Xauthority:/home/chronos/.Xauthority:rw
fi
docker pull --platform ${PLATFORM} ${REPOSITORY}/crewbuild:${name}-${ARCH}.m${milestone}
docker pull tonistiigi/binfmt
docker run --privileged --rm tonistiigi/binfmt --install all
$dockercmd
IMAGESCRIPTEOF
  chmod +x $(abspath "${outdir}")/crewbuild-"${name}"-"${ARCH}".m"${milestone}".sh
    }
enter_docker_image () {
  echo "Running \"$dockercmd\" from \"$(abspath "${outdir}")/crewbuild-${name}-${ARCH}.m${milestone}.sh\""
  echo "Entering in..." && countdown "00:00:30"
  exec "$(abspath "${outdir}")/crewbuild-${name}-${ARCH}.m${milestone}.sh"
}
main () {
  setup_base
  get_arch
  mkdir "${outdir}"/{autobuild,built,packages,preinstall,postinstall,src_cache,tmp,"${ARCH}"} &> /dev/null
  import_to_Docker
  ## This enables ipv6 for docker container
  #if ! docker container ls | grep ipv6nat  ; then
    #docker run -d --name ipv6nat --privileged --network host --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock:ro -v /lib/modules:/lib/modules:ro robbertkl/ipv6nat
  #fi
  rm crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  echo "build being logged to crewbuild-${name}-${ARCH}.m${milestone}-build.log"
  build_dockerfile 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  build_docker_image_with_docker_hub 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  make_cache_links 2>&1 |tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  build_docker_image 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  make_docker_image_script 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  [[ -z "$JUST_BUILD" ]] && enter_docker_image
}
main
