#!/bin/bash

set -e

ISO_PATH=$1

if [ ! -e "${ISO_PATH}" ]; then
	echo "ISO not found!" && exit 1
fi

ISO_NAME=$(basename "${ISO_PATH}" .iso)
TAG_NAME="${ISO_NAME/pentoo-/}"
REPO_NAME=wuodan/pentoo
BUILD_PATH=/tmp/iso2docker/${ISO_NAME}

echo "==> Create work dir"
mkdir -p "${BUILD_PATH}"

echo $ISO_NAME
echo $BUILD_PATH

echo "==> Mount ISO"
mkdir -p "${BUILD_PATH}"/ISO_mount
mount -o loop,ro "${ISO_PATH}" "${BUILD_PATH}"/ISO_mount

echo "==> check for enough meory to use tmpfs"
if [ "$(free | grep Mem | awk '{print $6}')" -gt "$((14 * 1024 * 1024))" ]; then
	echo "==> use tmpfs"
	mount -o size=14G -t tmpfs tmpfs "${BUILD_PATH}"
else
	echo "==> don't use tmpfs"
fi

echo "==> unsquash /"
unsquashfs -d "${BUILD_PATH}"/squashfs-root "${BUILD_PATH}"/ISO_mount/image.squashfs
echo "==> unsquash portage and pentoo"
for f  in "${BUILD_PATH}"/ISO_mount/modules/*.lzm; do
	unsquashfs -f -d "${BUILD_PATH}"/squashfs-root "${f}"
done

echo "==> tar and import to docker"
tar -C "${BUILD_PATH}"/squashfs-root  -c . | docker import - ${REPO_NAME}:${TAG_NAME}

echo "==> cleanup"
umount "${BUILD_PATH}"/ISO_mount
if [ mount | grep -q "${BUILD_PATH} " ]; then
	echo "==> unmounting tmpfs"
	umoount "${BUILD_PATH}"
else
	echo "==> deleting"
	rmdir "${BUILD_PATH}/ISO_mount"
	rm -rf "${BUILD_PATH}"/squashfs-root
fi

rmdir "${BUILD_PATH}"

echo "==> DONE"
