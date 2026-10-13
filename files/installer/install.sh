#!/bin/sh

. /lib/upgrade/nand.sh
. /lib/functions/system.sh

sleep 1

echo
echo OpenWrt UBI installer
echo

INSTALLER_DIR="/installer"
PRELOADER="$INSTALLER_DIR/bl2.bin"
FIP="$INSTALLER_DIR/fip.bin"

install_prepare_ubi() {
	ubidetach -p /dev/mtd2 2>/dev/null || true
	ubiformat /dev/mtd2 -y
	ubiattach -p /dev/mtd2

	while [ ! -d /sys/class/ubi/ubi0 ]; do sleep 1; done
	ubi_mknod ubi0 || true
	[ -e /dev/ubi0 ] || mknod /dev/ubi0 c $(cut -d: -f1 /sys/class/ubi/ubi0/dev) $(cut -d: -f2 /sys/class/ubi/ubi0/dev)

	ubimkvol /dev/ubi0 -n 0 -t static -s 1048576 -N fip && \
		ubi_mknod ubi0_0 && \
		ubiupdatevol /dev/ubi0_0 $FIP

	ubimkvol /dev/ubi0 -n 1 -t static -s 262144 -N reservedarea && \
		ubi_mknod ubi0_1 && \
		ubiupdatevol /dev/ubi0_1 "/tmp/factory"

	ubimkvol /dev/ubi0 -n 2 -s 126976 -N ubootenv
	ubimkvol /dev/ubi0 -n 3 -s 126976 -N ubootenv2
}

echo
echo Write PRELOADER
echo

insmod mtd-rw i_want_a_brick=1
mtd unlock bl2

sleep 2

tr '\000' '\377' < /dev/zero | dd of=/tmp/bl2.bin bs=1 count=2048 2>/dev/null
cat $PRELOADER >> /tmp/bl2.bin

mtd write /tmp/bl2.bin bl2

echo
echo Prepare empty FACTORY
echo

dd if=/dev/zero bs=$((0x40000)) count=1 | tr '\000' '\377' > /tmp/factory

echo
echo Prepare UBI
echo

install_prepare_ubi

echo
echo REBOOT
echo

sync
sleep 5
reboot
