FROM golang:1.22.2-bookworm AS composeapp
# Build composeapp
WORKDIR /build
RUN git clone https://github.com/foundriesio/composeapp.git && cd composeapp \
    && git checkout v95.1 \
    && STOREROOT=/var/sota/reset-apps COMPOSEROOT=/var/sota/compose-apps BASESYSTEMCONFIG=/usr/lib/docker make \
    && cp ./bin/composectl /usr/bin/

FROM foundries/aklite-dev:ubuntu-25.04 AS aklite

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
