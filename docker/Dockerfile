FROM foundries/aklite-dev as aklite

ARG CCACHE_DIR=${PWD}/.ccache
ENV CCACHE_DIR =${CCACHE_DIR}
ARG AKLITE_VER=mp-93
ENV AKLITE_VER=${AKLITE_VER}

WORKDIR /aklite
RUN git clone https://github.com/foundriesio/aktualizr-lite.git && cd aktualizr-lite && git submodule update --init --recursive && git checkout ${AKLITE_VER}
WORKDIR /aklite/aktualizr-lite
RUN make -f dev-flow.mk config install && ldconfig

RUN  apt-get install -y g++ libboost-program-options-dev libboost-filesystem-dev libboost-iostreams-dev

RUN git clone https://github.com/foundriesio/lmp-device-register \
  && cd lmp-device-register && git checkout mp-90 \
  && cmake -S . -B ./build -DHARDWARE_ID=intel-corei7-64 && cmake --build ./build --target install

