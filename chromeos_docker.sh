#!/bin/bash
# Copyright 2021-2023 Satadru Pramanik
# Copyright 2023 Maximilian Downey Twiss
# SPDX-License-Identifier: GPL-3.0-or-later
name="${1}"
milestone="${2}"
: "${REPOSITORY:=satmandu}"
echo "       name: ${name}"
echo "  milestone: ${milestone}"
echo " REPOSITORY: ${REPOSITORY}"

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
  cp .dockerignore ./"${ARCH}"
  name=${name} milestone=${milestone} REPOSITORY=${REPOSITORY} CREW_LIB_PREFIX=${CREW_LIB_PREFIX} CREW_KERNEL_VERSION=${CREW_KERNEL_VERSION} envsubst '$name $milestone $REPOSITORY $ARCH $CREW_LIB_PREFIX $CREW_KERNEL_VERSION' < Dockerfile > ./"${ARCH}"/Dockerfile
}
build_docker_image_with_docker_hub () {
  docker ps
  echo "Tag & Push starting in ..." && countdown "00:00:01"
  if ! docker pull "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}" ; then 
  docker tag "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}" "${REPOSITORY}"/crewbase:"${DOCKER_PLATFORM}"
  docker push "${REPOSITORY}"/crewbase:"${name}"-"${ARCH}".m"${milestone}"
fi
}
build_docker_image () {
  docker image ls
  dangling_images=$(docker images --filter "dangling=true" -q --no-trunc)
  [[ -n "$dangling_images" ]] && docker rmi -f $(docker images --filter "dangling=true" -q --no-trunc)
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
main () {
  setup_base
  get_arch
  import_to_Docker
  ## This enables ipv6 for docker container
  #if ! docker container ls | grep ipv6nat  ; then
    #docker run -d --name ipv6nat --privileged --network host --restart unless-stopped -v /var/run/docker.sock:/var/run/docker.sock:ro -v /lib/modules:/lib/modules:ro robbertkl/ipv6nat
  #fi
  rm crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  echo "build being logged to crewbuild-${name}-${ARCH}.m${milestone}-build.log"
  build_dockerfile 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  build_docker_image_with_docker_hub 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
  build_docker_image 2>&1 | tee -a crewbuild-"${name}"-"${ARCH}".m"${milestone}"-build.log
}
main
