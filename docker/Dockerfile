FROM golang:1.22.2-bookworm AS composeapp
# Build composeapp
WORKDIR /build
RUN git clone https://github.com/foundriesio/composeapp.git && cd composeapp \
    && STOREROOT=/var/sota/reset-apps COMPOSEROOT=/var/sota/compose-apps BASESYSTEMCONFIG=/usr/lib/docker make \
    && cp ./bin/composectl /usr/bin/

FROM foundries/aklite-dev as aklite

ARG CCACHE_DIR=${PWD}/.ccache
ENV CCACHE_DIR =${CCACHE_DIR}
ARG AKLITE_VER=master
ENV AKLITE_VER=${AKLITE_VER}

WORKDIR /aklite
RUN git clone https://github.com/foundriesio/aktualizr-lite.git && cd aktualizr-lite && git submodule update --init --recursive && git checkout ${AKLITE_VER}
WORKDIR /aklite/aktualizr-lite
RUN make -f dev-flow.mk config install && ldconfig


# Install composectl
COPY --from=composeapp /build/composeapp/bin/composectl /usr/bin/

# Install lmp-device-register
RUN  apt-get install -y libboost-iostreams-dev

RUN git clone https://github.com/foundriesio/lmp-device-register \
  && cd lmp-device-register && git checkout mp-90 \
  && cmake -S . -B ./build -DDOCKER_COMPOSE_APP=ON -DHARDWARE_ID=intel-corei7-64 && cmake --build ./build --target install


# Add Docker's official GPG key:
RUN apt-get update && apt-get install -y ca-certificates curl
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN apt-get update && apt-get install -y docker-ce-cli docker-compose-plugin

# Install docker credential helper and auth configuration
COPY config.json /usr/lib/docker/config.json
COPY docker-credential-fio-helper /usr/bin/docker-credential-fio-helper

# Install gosu required for the entry/startup script to add a user and group in the container
RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
