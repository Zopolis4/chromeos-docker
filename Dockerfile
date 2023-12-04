# syntax=docker/dockerfile:1.3-labs
ARG UID=1000
FROM ${REPOSITORY}/crewbase:${name}-${ARCH}.m${milestone} AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"
#ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CREW_LIB_PREFIX
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
COPY .bashrc /home/chronos/user/
COPY chromebrewstart /bin/
RUN --mount=type=bind,target=/input <<EOF1
passwd -d chronos
echo "chronos ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Defaults env_keep+=\"LOCALRC\"" >> /etc/sudoers
# Create /var/run/chrome - this is used by some X11 apps.
mkdir -p /var/run/chrome
chown chronos:chronos /var/run/chrome
chmod +x /bin/chromebrewstart
if [[ -f /input/install.sh.test ]]; then
  cp /input/install.sh.test /home/chronos/user/install.sh
  echo "Using local installer script install.sh.test!"
else
  curl -Ls https://github.com/$OWNER/$REPO/raw/$BRANCH/install.sh -o /home/chronos/user/install.sh
fi
chown chronos /usr/local
chown chronos /home/chronos/user/install.sh
chmod +x /home/chronos/user/install.sh
EOF1
# crew_profile_base isn't getting postinstall run on i686
SHELL ["/usr/bin/sudo", "-E", "-n", "BASH_ENV=/home/chronos/user/.bashrc", "-u", "chronos", "/bin/bash", "-c"]
RUN --mount=type=bind,target=/input <<EOF2
PATH=/usr/local/bin:/usr/local/sbin:$PATH   OWNER=$OWNER   BRANCH=$BRANCH   CREW_FORCE_INSTALL=1   CREW_KERNEL_VERSION=$CREW_KERNEL_VERSION   /bin/bash /home/chronos/user/install.sh
cd /usr/local/lib/crew/packages
echo "Disk Space used by initial install:"
du -ahx /usr/local | tail
echo "Packages installed but not in core_packages.txt:"
comm -13 <(cat ../tools/core_packages.txt| sort) <(crew -d list installed| sort)
LD_LIBRARY_PATH=$CREW_LIB_PREFIX:$LD_LIBRARY_PATH   crew postinstall crew_profile_base
yes | LD_LIBRARY_PATH=$CREW_LIB_PREFIX:$LD_LIBRARY_PATH   crew install util_linux psmisc
  crew install util_linux psmisc
EOF2
# We can use setarch now that util_linux is installed.
SHELL ["/usr/bin/sudo", "-E", "-n", "BASH_ENV=/home/chronos/user/.bashrc", "-u", "chronos", "setarch", "$ARCH", "/bin/bash", "-o", "pipefail", "-c"]
COPY .bash_profile /home/chronos/user/
RUN --mount=type=bind,target=/input <<EOF3
yes |   LD_LIBRARY_PATH=/lib64:$LD_LIBRARY_PATH   PATH=/usr/local/bin:/usr/local/sbin:$PATH   crew install buildessential || true
  if gem list -i "^rubocop$" ; then
  echo 'Running gem update -N --system'
    gem update -N --system
  else
    echo 'Running  gem install -N rubocop --conservative'
    gem install -N rubocop --conservative
  fi
  if ! gem list -i "^concurrent-ruby$" ; then
    echo 'Running gem install -N concurrent-ruby --conservative'
    gem install -N concurrent-ruby --conservative
  fi
EOF3
CMD /bin/chromebrewstart
