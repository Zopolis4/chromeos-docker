# Use the previously created filesystem as a base
ARG CREWBASE
FROM ${CREWBASE}
# Pass the kernel version that would be present on the original board through
ARG CREW_KERNEL_VERSION
ENV CREW_KERNEL_VERSION=${CREW_KERNEL_VERSION}
# Setup chronos user with no password and sudo permissions
RUN passwd -d chronos
RUN echo "chronos ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Run as the chronos user
USER chronos
# Install chromebrew
RUN curl -Ls git.io/vddgY | CREW_FORCE_INSTALL=1 bash
