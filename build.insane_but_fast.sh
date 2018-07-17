#!/bin/bash

set -e

ISO_PATH=$1

if [ ! -e "${ISO_PATH}" ]; then
	echo "ISO not found!" && exit 1
fi

ISO_NAME=$(basename "${ISO_PATH}" .iso)
# TAG_NAME="${ISO_NAME/pentoo-/}"
# REPO_NAME=wuodan/pentoo
BUILD_PATH=/tmp/iso2docker/${ISO_NAME}

echo "==> Create work dirs"
mkdir -p "${BUILD_PATH}"/{ISO_mount,image.squashfs,dest,upper,work}

echo $ISO_NAME
echo $BUILD_PATH

echo "==> Mount ISO contents"
mount -o loop,ro \
	"${ISO_PATH}" \
	"${BUILD_PATH}"/ISO_mount
mount -o loop,ro \
	"${BUILD_PATH}"/ISO_mount/image.squashfs \
	"${BUILD_PATH}"/image.squashfs
for module in "${BUILD_PATH}"/ISO_mount/modules/*.lzm; do
	mkdir -p "${BUILD_PATH}"/"$(basename $module)"
	mount -o loop \
		"${BUILD_PATH}"/ISO_mount/modules/"$(basename $module)" \
		"${BUILD_PATH}"/"$(basename $module)"
done

OVERLAY_DIRS=lowerdir="${BUILD_PATH}"/image.squashfs
for module in "${BUILD_PATH}"/ISO_mount/modules/*.lzm; do
	OVERLAY_DIRS+=:"${BUILD_PATH}"/"$(basename $module)"
done
OVERLAY_DIRS+=,upperdir="${BUILD_PATH}"/upper,workdir="${BUILD_PATH}"/work

mount -t overlay overlay \
	-o "${OVERLAY_DIRS}" "${BUILD_PATH}"/dest

# docker does not allow mounting / .. so we cheat and mount all folders
# get all dirs in / except proc, dev, sys, run
DOCKER_VOLUMES="$(for dir in $(ls -dl "${BUILD_PATH}"/dest/*/ | awk '{print $9}'); do basename $dir; done)"
DOCKER_VOLUMES="$(echo "${DOCKER_VOLUMES}" | grep -Ev -e '(proc|dev|sys|run)')"
DOCKER_VOLUMES="$(echo "$DOCKER_VOLUMES" | sed -E "s#^.+\$# -v ${BUILD_PATH}/dest/\0:/\0:rw#")"
DEVICE_DISK=/dev/sda
DEVICE_HWCLOCK="$(hwclock --verbose 2>&1 | sed -En -e 's#^Trying to open: (.+)$#\1#p' | tail -n 1)"

echo ###
echo "${DOCKER_VOLUMES}"
echo ###

docker build -t my_scratch $(dirname "$0")

#--cap-add SYS_TIME \
#--cap-add AUDIT_CONTROL \
docker run \
	-it \
	--rm \
	--device "${DEVICE_DISK}" \
	--device "${DEVICE_HWCLOCK}" \
	--cap-add SYS_MODULE \
	--cap-add SYS_RAWIO \
	--cap-add SYS_PACCT \
	--cap-add SYS_ADMIN \
	--cap-add SYS_NICE \
	--cap-add SYS_RESOURCE \
	--cap-add SYS_TIME \
	--cap-add SYS_TTY_CONFIG \
	--cap-add AUDIT_CONTROL \
	--cap-add MAC_ADMIN \
	--cap-add MAC_OVERRIDE \
	--cap-add NET_ADMIN \
	--cap-add SYSLOG \
	--cap-add DAC_READ_SEARCH \
	--cap-add LINUX_IMMUTABLE \
	--cap-add NET_BROADCAST \
	--cap-add IPC_LOCK \
	--cap-add IPC_OWNER \
	--cap-add SYS_PTRACE \
	--cap-add SYS_BOOT \
	--cap-add LEASE \
	--cap-add WAKE_ALARM \
	--cap-add BLOCK_SUSPEND \
	--name pentoo \
	${DOCKER_VOLUMES} \
	-v "${BUILD_PATH}"/ISO_mount:/mnt/cdrom \
	-v "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"/share_bin:/mnt/share_bin \
	my_scratch \
		/mnt/share_bin/start.sh
