#!/usr/bin/bash

#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#

#
# Copyright 2017 OmniTI Computer Consulting, Inc. All rights reserved.
#

if [[ `id -u` != "0" ]]; then
	echo "You must be root to run this script."
	exit 1
fi

PROTO=/tmp/proto
KAYAK_ROOT=/rpool/kayak_image/root
MNT=/mnt
UFS_LOFI=/tmp/boot_archive
LOFI_SIZE=600M
DST_ISO=/tmp/foo.iso
ZFS_IMG=/rpool/kayak_image/*.bz2

mkfile $LOFI_SIZE $UFS_LOFI
LOFI_PATH=`lofiadm -a $UFS_LOFI`
echo 'y' | newfs $LOFI_PATH
mount $LOFI_PATH $MNT
tar -cf - -C $KAYAK_ROOT . | tar -xf - -C $MNT
mkdir $PROTO
tar -cf - -C $KAYAK_ROOT . | tar -xf - -C $PROTO

# Put additional goodies into the boot-archive, which is what'll be / on
# the booted ISO.
cp $ZFS_IMG $MNT/root/.
echo "export PATH=/usr/bin:/usr/sbin:/sbin" > $MNT/root/.profile
cp kayak-menu.sh $MNT/usr/sbin/kayak-menu.sh
chmod 0755 $MNT/usr/sbin/kayak-menu.sh
# XXX KEBE SAYS MORE...

devfsadm -r $MNT

umount $MNT
lofiadm -d $LOFI_PATH
cp $UFS_LOFI $PROTO/platform/i86pc/amd64/boot_archive
digest -a sha1 $UFS_LOFI > $PROTO/platform/i86pc/amd64/boot_archive.hash
rm -rf $PROTO/{usr,bin,sbin,lib,kernel}
du -sh $PROTO/.
mkisofs -o $DST_ISO -b boot/cdboot -c .catalog -no-emul-boot -boot-load-size 4 -boot-info-table -N -l -R -U -allow-multidot -no-iso-translate -cache-inodes -d -D -V OmniOS $PROTO

rm -rf $PROTO $UFS_LOFI
echo "$DST_ISO is ready"
ls -lt $DST_ISO
