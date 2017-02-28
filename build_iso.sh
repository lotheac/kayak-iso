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
KAYAK_ROOTBALL=/rpool/kayak_image/miniroot.gz
KAYAK_ROOT=/tmp/miniroot.$$
#KAYAK_ROOT=/rpool/kayak_image/root
MNT=/mnt
UFS_LOFI=/tmp/boot_archive
LOFI_SIZE=600M
DST_ISO=/tmp/foo.iso
ZFS_IMG=/rpool/kayak_image/*.bz2

mkfile $LOFI_SIZE $UFS_LOFI
LOFI_PATH=`lofiadm -a $UFS_LOFI`
echo 'y' | newfs $LOFI_PATH
mount $LOFI_PATH $MNT
gunzip -c $KAYAK_ROOTBALL > /tmp/kr.$$
LOFI_RPATH=`lofiadm -a /tmp/kr.$$`
mkdir $KAYAK_ROOT
mount $LOFI_RPATH $KAYAK_ROOT
tar -cf - -C $KAYAK_ROOT . | tar -xf - -C $MNT
mkdir $PROTO
tar -cf - -C $KAYAK_ROOT . | tar -xf - -C $PROTO

# Ugggh, instead of maintaining a list of zoneinfo files, just tar a copy
# of zoneinfo.  Use PREBUILT_ILLUMOS if possible...
ZIPATH=usr/share/lib/zoneinfo
if [[ -z $PREBUILT_ILLUMOS ]]; then
    ZIROOT=/
else
    ZIROOT=$PREBUILT_ILLUMOS/proto/root_i386
fi
tar -cf - -C $ZIROOT/$ZIPATH . | tar -xf - -C $MNT/$ZIPATH

umount $KAYAK_ROOT
rmdir $KAYAK_ROOT
lofiadm -d $LOFI_RPATH
rm /tmp/kr.$$

# Put additional goodies into the boot-archive, which is what'll be / on
# the booted ISO.
cp $ZFS_IMG $MNT/root/.
cat <<EOF > $MNT/root/.bashrc
export PATH=/usr/bin:/usr/sbin:/sbin
export HOME=/root
EOF
# Have initialboot muck with the console login service to make an interactive
# installer get invoked.
cat <<EOF > $MNT/.initialboot
/usr/sbin/svccfg -s console-login:default addpg startd framework
/usr/sbin/svccfg -s console-login:default setprop startd/need_session = boolean: true
/usr/sbin/svcadm refresh console-login:default
/usr/sbin/svcadm restart console-login:default
EOF
cat <<EOF > $MNT/lib/svc/method/console-login
#!/bin/bash

# CHEESY way to get the kayak-menu running w/o interference.
export TERM=sun-color
/kayak/kayak-menu.sh < /dev/console >& /dev/console
EOF
chmod 0755 $MNT/lib/svc/method/console-login
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
