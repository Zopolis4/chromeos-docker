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

    # Additionally, 7zip does not currently preserve the required permissions or uid bits when extracting
    # 7z x -snld 2.ROOT-A.img -o"${cached_image}"
#     virt-copy-out -a 2.ROOT-A.img / ${cached_image}

    # Tar the unpacked filesystem for importing into docker
    (cd "${cached_image}" && tar -pcf ../"${cached_image}".tar .)

    # Clean up after ourselves
    rm -f "${cached_image}".zip "${cached_image}".bin 2.ROOT-A.img
    rm -rf "${cached_image}"

    # If we don't already have the image cached, we don't already have it imported into docker and pushed to the repository
    docker import "${cached_image}".tar --platform "${PLATFORM}" "${REPOSITORY}"/crewbase:"${name}".m"${milestone}"
    docker push "${REPOSITORY}"/crewbase:"${name}".m"${milestone}"
  else
    echo "Cached image found for ${cached_image}, skipping download, import and push."
  fi
}

get_arch () {
  kernel_arch="$(jq -r ."${name}"[\""Kernel ABI"\"] boards.json)"
  case $kernel_arch in
    x86_64)  PLATFORM="linux/amd64";;
    x86)     PLATFORM="linux/386";;
    arm)     PLATFORM="linux/arm";;
    aarch64) PLATFORM="linux/arm64";;
  esac
  CREW_KERNEL_VERSION="$(jq -r ."${name}"[\""Kernel Version"\"] boards.json)"
}
build_docker_image () {
  name=${name} milestone=${milestone} REPOSITORY=${REPOSITORY} CREW_KERNEL_VERSION=${CREW_KERNEL_VERSION} envsubst '$name $milestone $REPOSITORY $CREW_KERNEL_VERSION' < base_Dockerfile > Dockerfile
  docker buildx create --name builder --driver docker-container --use
  docker buildx build --push --platform ${PLATFORM} --tag ${REPOSITORY}/crewbuild:${name}.m${milestone} .
  rm -f Dockerfile
}
main () {
  get_arch
  setup_base
  build_docker_image
}
main
