#!/usr/bin/bash

set -e

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

#
# Build a USB installer using the Kayak tools.
#

if [[ `id -u` != "0" ]]; then
	echo "You must be root to run this script."
	exit 1
fi

if [[ -z $BUILDSEND_MP ]]; then
	echo "Using /rpool/kayak_image for BUILDSEND_MP"
	BUILDSEND_MP=/rpool/kayak_image
fi

if [[ -z $VERSION ]]; then
        echo "\$VERSION not set" >&2
        exit 1
fi

# Many of these depend on sufficient space in /tmp by default.  Please
# modify as you deem appropriate.
TMPDIR=${TMPDIR-/tmp}
PROTO=${TMPDIR}/proto
KAYAK_ROOTBALL=$BUILDSEND_MP/miniroot.gz
KAYAK_ROOT=${TMPDIR}/miniroot.$$
KR_FILE=${TMPDIR}/kr.$$
MNT=/mnt
UFS_LOFI=${TMPDIR}/boot_archive
LOFI_SIZE=2000M
DST_IMG=${BUILDSEND_MP}/${VERSION}.img
ZFS_IMG=$BUILDSEND_MP/kayak_${VERSION}.zfs.bz2

cleanup() {
    echo "cleaning up"
    set +e
    umount $MNT 2>/dev/null
    umount $KAYAK_ROOT 2>/dev/null
    rm -rf $PROTO $UFS_LOFI $KR_FILE $KAYAK_ROOT
    lofiadm -d $DST_IMG 2>/dev/null
    lofiadm -d $LOFI_PATH 2>/dev/null
    lofiadm -d $LOFI_RPATH 2>/dev/null
    lofiadm -d $KR_FILE 2>/dev/null
}
trap cleanup 0 INT TERM

# Create a UFS lofi file and mount the UFS filesystem in $MNT.  This will
# form the boot_archive for the USB.
mkfile $LOFI_SIZE $UFS_LOFI
LOFI_PATH=`lofiadm -a $UFS_LOFI`
echo 'y' | newfs $LOFI_PATH
mount $LOFI_PATH $MNT

# Clone the already-created Kayak miniroot and copy it into both $MNT, and
# into a now-created $PROTO. $PROTO will form the directory that gets
# sprayed onto the USB.
gunzip -c $KAYAK_ROOTBALL > $KR_FILE
LOFI_RPATH=`lofiadm -a $KR_FILE`
mkdir $KAYAK_ROOT
mount $LOFI_RPATH $KAYAK_ROOT
tar -cf - -C $KAYAK_ROOT . | tar -xf - -C $MNT
mkdir $PROTO
tar -cf - -C $KAYAK_ROOT . | tar -xf - -C $PROTO
umount $KAYAK_ROOT
rmdir $KAYAK_ROOT
lofiadm -d $LOFI_RPATH
rm $KR_FILE

#
# Put additional goodies into the boot-archive on $MNT, which is
# what'll be / (via ramdisk) once one boots the USB.
# 

# The full ZFS image (also already-created) for actual installation.
cp $ZFS_IMG $MNT/root/.

# A cheesy way to get the boot menu to appear at boot time.
cp -p ./takeover-console $MNT/kayak/.
cat <<EOF > $MNT/root/.bashrc
export PATH=/usr/bin:/usr/sbin:/sbin
export HOME=/root
EOF

# Refresh the devices on the miniroot.
devfsadm -r $MNT

#
# The USB's miniroot is going to be larger than the PXE miniroot.  To that
# end, some files not listed in the exception list do need to show up on
# the miniroot.  Use PREBUILT_ILLUMOS if available, or the current system
# if not.
#
from_one_to_other() {
    dir=$1
    if [[ -z $PREBUILT_ILLUMOS || ! -d $PREBUILT_ILLUMOS/proto/root_i386/$dir ]]
    then
	FROMDIR=/
    else
	FROMDIR=$PREBUILT_ILLUMOS/proto/root_i386
    fi

    shift
    tar -cf - -C $FROMDIR/$dir ${@:-.} | tar -xf - -C $MNT/$dir
}

# Add from_one_to_other for any directory {file|subdir file|subdir ...} you need
from_one_to_other usr/share/lib/zoneinfo
from_one_to_other usr/share/lib/keytables
from_one_to_other usr/share/lib/terminfo
from_one_to_other usr/gnu/share/terminfo
from_one_to_other usr/sbin ping
from_one_to_other usr/bin netstat

cat <<EOF > $PROTO/boot/loader.conf.local
loader_menu_title="Welcome to the unleashed installer"
autoboot_delay=5
console="text,ttya"
EOF

#
# Okay, we've populated the new miniroot.  Close it up and install it on $PROTO
# as the boot archive.
#
umount $MNT
lofiadm -d $LOFI_PATH
gzip -c $UFS_LOFI > $PROTO/platform/i86pc/amd64/boot_archive
digest -a sha1 $UFS_LOFI > $PROTO/platform/i86pc/amd64/boot_archive.hash
rm -rf $PROTO/{usr,bin,sbin,lib,kernel}
protosize=$(du -sm $PROTO/.|cut -f1)
imagesize=$((protosize * 11/10))

rm -f "${DST_IMG}"
mkfile -n ${imagesize}M "${DST_IMG}"
devs="$(lofiadm -la "${DST_IMG}")"
rdevs="${devs/dsk/rdsk}"
s0devs="${devs/p0/s0}"
rs0devs="${rdevs/p0/s0}"
rs2devs="${rdevs/p0/s2}"
fdisk -B "${rdevs}"
prtvtoc "${rs2devs}" | nawk '
/^[^\*]/ { r = $1; for(n = 1; n <= NF; n++) vtoc[r,n] = $n }
END {
vtoc[0,1] = 0;
vtoc[0,2] = 2;
vtoc[0,3] = 00;
vtoc[0,4] = vtoc[8,6] + 1;
vtoc[0,5] = vtoc[2,6] - vtoc[8,6];
vtoc[0,6] = vtoc[2,6];
printf("\t%d\t%d\t%02d\t%d\t%d\t%d\n",
	vtoc[0,1], vtoc[0,2], vtoc[0,3], vtoc[0,4], vtoc[0,5], vtoc[0,6]);
printf("\t%d\t%d\t%02d\t%d\t%d\t%d\n",
	vtoc[2,1], vtoc[2,2], vtoc[2,3], vtoc[2,4], vtoc[2,5], vtoc[2,6]);
printf("\t%d\t%d\t%02d\t%d\t%d\t%d\n",
	vtoc[8,1], vtoc[8,2], vtoc[8,3], vtoc[8,4], vtoc[8,5], vtoc[8,6]);
}' | fmthard -s- "${rs2devs}"
# newfs doesn't ask questions if stdin isn't a tty.
newfs "${rs0devs}" </dev/null
mount -o nologging "${s0devs}" $MNT
tar cf - -C $PROTO . | tar xf - -C $MNT
installboot -mf "${MNT}/boot/pmbr" "${MNT}/boot/gptzfsboot" "${rs0devs}"

chmod 0444 $DST_IMG
echo "$DST_IMG is ready"
trap '' 0
cleanup || true
