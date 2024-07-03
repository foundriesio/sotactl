CXX ?= clang++
CC ?= clang
BUILD_DIR ?= build
CCACHE_DIR = $(shell pwd)/.ccache
TARGET ?= sotactl
BIN = ${BUILD_DIR}/${TARGET}

SOTA_DIR ?= ${PWD}/.device/sota
DEVICE_FACTORY ?= ${FACTORY}
DEVICE_TOKEN ?= ${AUTH_TOKEN}

OSTREE_SYSROOT ?= ${PWD}/.device/.sysroot
INIT_ROOTFS ?= ${PWD}/.device/.init-rootfs
OS ?= lmp

.PHONY: config build

all: config build

config:
	cmake -S . -B ${BUILD_DIR} -DCMAKE_BUILD_TYPE=Debug -GNinja -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_C_COMPILER=${CC}

build: config
	cmake --build ${BUILD_DIR} --target ${TARGET}

${SOTA_DIR}:
	mkdir -p ${SOTA_DIR}

register: ${SOTA_DIR}
	DEVICE_FACTORY=${DEVICE_FACTORY} lmp-device-register -T ${DEVICE_TOKEN} --start-daemon 0 -d ${SOTA_DIR} -t master
	@echo "[pacman]\nsysroot = ${OSTREE_SYSROOT}" > ${SOTA_DIR}/z-90-ostree-sysroot-path.toml
	@echo "os = ${OS}" >> ${SOTA_DIR}/z-90-ostree-sysroot-path.toml
	@echo "booted = 0" >> ${SOTA_DIR}/z-90-ostree-sysroot-path.toml
	@echo "[bootloader]\nreboot_sentinel_dir = ${SOTA_DIR}" > ${SOTA_DIR}/z-91-bootloader.toml
	@echo "reboot_command = /usr/bin/true" >> ${SOTA_DIR}/z-91-bootloader.toml

unregister:
	@rm -rf ${SOTA_DIR}/sql.db
	@rm ${SOTA_DIR}/*.toml

${OSTREE_SYSROOT}:
	@mkdir -p ${OSTREE_SYSROOT}

ostree: ${OSTREE_SYSROOT}
	@ostree admin init-fs ${OSTREE_SYSROOT}
	@OSTREE_SYSROOT=${OSTREE_SYSROOT} ostree admin os-init ${OS}
	@ostree config --repo="${OSTREE_SYSROOT}/ostree/repo" set core.mode bare-user
	@/aklite/aktualizr-lite/tests/make_sys_rootfs.sh ${INIT_ROOTFS} lmp intel-corei7-64 lmp
	@COMMIT=$$(ostree --repo="${OSTREE_SYSROOT}/ostree/repo" commit ${INIT_ROOTFS} --branch lmp); \
	ostree admin --sysroot=${OSTREE_SYSROOT} deploy --os=lmp $$COMMIT
	@rm -rf ${INIT_ROOTFS}

check:
	${BIN} check

update:
	@ostree config --repo="${OSTREE_SYSROOT}/ostree/repo" set core.mode bare-user
	${BIN} pull
	@ostree config --repo="${OSTREE_SYSROOT}/ostree/repo" set core.mode bare-user-only
	${BIN} install

run:
	@rm -f ${SOTA_DIR}/need_reboot
	${BIN} run
