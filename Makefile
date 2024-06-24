FACTORYCXX ?= clang++
CC ?= clang
BUILD_DIR ?= build
CCACHE_DIR = $(shell pwd)/.ccache
TARGET ?= sotactl

DEVICE_DIR ?= ${PWD}/.device
DEVICE_FACTORY ?= ${FACTORY}
DEVICE_TOKEN ?= ${AUTH_TOKEN}

OSTREE_SYSROOT ?= ${PWD}/.sysroot
INIT_ROOTFS ?= ${PWD}/.init-rootfs
OS ?= lmp

.PHONY: config build

all: config build

config:
	cmake -S . -B ${BUILD_DIR} -DCMAKE_BUILD_TYPE=Debug -GNinja -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_C_COMPILER=${CC}

build: config
	cmake --build ${BUILD_DIR} --target ${TARGET}

${DEVICE_DIR}:
	mkdir -p ${DEVICE_DIR}

register: ${DEVICE_DIR}
	DEVICE_FACTORY=${DEVICE_FACTORY} lmp-device-register -T ${DEVICE_TOKEN} --start-daemon 0 -d ${DEVICE_DIR} -t master
	@echo "[pacman]\nsysroot = ${OSTREE_SYSROOT}" > ${DEVICE_DIR}/z-90-ostree-sysroot-path.toml
	@echo "os = ${OS}" >> ${DEVICE_DIR}/z-90-ostree-sysroot-path.toml
	@echo "booted = 0" >> ${DEVICE_DIR}/z-90-ostree-sysroot-path.toml
	@echo "[bootloader]\nreboot_sentinel_dir = ${DEVICE_DIR}" > ${DEVICE_DIR}/z-91-bootloader.toml
	@echo "reboot_command = /usr/bin/true" >> ${DEVICE_DIR}/z-91-bootloader.toml

unregister:
	rm -rf ${DEVICE_DIR}/sql.db
	rm ${DEVICE_DIR}/*.toml

${OSTREE_SYSROOT}:
	mkdir -p ${OSTREE_SYSROOT}

ostree: ${OSTREE_SYSROOT}
	ostree admin init-fs ${OSTREE_SYSROOT}
	OSTREE_SYSROOT=${OSTREE_SYSROOT} ostree admin os-init ${OS}
	ostree config --repo="${OSTREE_SYSROOT}/ostree/repo" set core.mode bare-user

init-rootfs:
	/aklite/aktualizr-lite/tests/make_sys_rootfs.sh ${INIT_ROOTFS} lmp intel-corei7-64 lmp
	COMMIT=$$(ostree --repo="${OSTREE_SYSROOT}/ostree/repo" commit ${INIT_ROOTFS} --branch lmp); \
	ostree admin --sysroot=${OSTREE_SYSROOT} deploy --os=lmp $$COMMIT

check-meta:
	AKLITE_CONFIG_DIR=${DEVICE_DIR} ${BUILD_DIR}/${TARGET} check

run-update:
	ostree config --repo="${OSTREE_SYSROOT}/ostree/repo" set core.mode bare-user
	AKLITE_CONFIG_DIR=${DEVICE_DIR} ${BUILD_DIR}/${TARGET} pull
	ostree config --repo="${OSTREE_SYSROOT}/ostree/repo" set core.mode bare-user-only
	AKLITE_CONFIG_DIR=${DEVICE_DIR} ${BUILD_DIR}/${TARGET} install

run-finalize:
	rm -f ${DEVICE_DIR}/need_reboot
	AKLITE_CONFIG_DIR=${DEVICE_DIR} ${BUILD_DIR}/${TARGET} run
