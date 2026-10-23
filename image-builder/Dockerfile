FROM ubuntu:24.04

# Used to match the host UID to the container UID
ARG BUILD_UID=1000
ENV HOME=/home/ubuntu \
    IMAGE_BUILDER="https://github.com/kubernetes-sigs/image-builder" \
    BUILD_UID=$BUILD_UID

RUN apt update && apt upgrade -y && \
    apt install -y vim git curl unzip findutils diffutils less \
    python3 python-is-python3 python3-pip jq build-essential \
    ca-certificates gnupg \
    python3-openstackclient python3-magnumclient \
    python3-octaviaclient python3-designate && \
    apt clean && rm -rf /var/lib/apt/lists/*

USER ubuntu

# Begin image-builder
WORKDIR $HOME

# $HOME/.local/bin is the ansible install path
# $HOME/image-builder/images/capi/.local/bin is the packer install path
ENV PATH=$HOME/.local/bin:$HOME/image-builder/images/capi/.local/bin:$PATH
RUN git clone $IMAGE_BUILDER && \
    cd image-builder/images/capi/ && \
    make deps-openstack
# End image-builder

WORKDIR $HOME/image-builder/images/capi
    
COPY --chmod=+x run.sh ./run.sh

# Finally, ensure UID matches that of the host
# `usermod -u` will update home directory uid ownership
USER root
RUN usermod -ou $BUILD_UID ubuntu && \
    mkdir /image-builder-log && chown -R ubuntu /image-builder-log
USER ubuntu

# Start container
CMD ["bash", "run.sh"]
ENTRYPOINT ["/usr/bin/env"]
