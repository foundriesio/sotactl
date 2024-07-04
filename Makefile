CXX ?= clang++
CC ?= clang
BUILD_DIR ?= build
CCACHE_DIR = $(shell pwd)/.ccache
TARGET ?= sotactl
BIN = ${BUILD_DIR}/${TARGET}

OS = lmp
SOTA_DIR = /var/sota

DEVICE_FACTORY ?= ${FACTORY}
DEVICE_TOKEN ?= ${AUTH_TOKEN}

.PHONY: config build

all: config build

config:
	cmake -S . -B ${BUILD_DIR} -DCMAKE_BUILD_TYPE=Debug -GNinja -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_C_COMPILER=${CC}

build: config
	cmake --build ${BUILD_DIR} --target ${TARGET}

${SOTA_DIR}:
	mkdir -p ${SOTA_DIR}/reset-apps
	mkdir -p ${SOTA_DIR}/compose-apps

register: ${SOTA_DIR}
	DEVICE_FACTORY=${DEVICE_FACTORY} lmp-device-register -T ${DEVICE_TOKEN} --start-daemon 0 -d ${SOTA_DIR} -t master

unregister:
	@rm -rf ${SOTA_DIR}/sql.db
	@rm ${SOTA_DIR}/*.toml

check:
	${BIN} check

update:
	@ostree config set core.mode bare-user
	${BIN} pull
	@ostree config set core.mode bare-user-only
	${BIN} install

reboot:
	@rm -f /var/run/aktualizr-session/need_reboot

run:
	${BIN} run
