#!/bin/bash
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Copyright 2012 OmniTI Computer Consulting, Inc.  All rights reserved.
# Use is subject to license terms.
#
fail() {
  echo $*
  exit 1
}

PUBLISHER=unleashed
PKGURL=${PKGURL-/usr/nightly/packages/i386/nightly/repo.redist}
: ${BZIP2:=bzip2}
ZROOT=rpool
OUT=
CLEANUP=0
set -- `getopt cd:o:p: $*`
for i in $*
do
  case $i in
    -c) CLEANUP=1; shift ;;
    -d) ZROOT=$2; shift 2;;
    -o) OUT=$2; shift 2;;
    -p) PROFILE=$2; shift 2;;
    -P) PUBLISHER_OVERRIDE=1; shift ;;
    --) shift; break ;;
  esac
done

USERLAND_PACKAGES='gnu-tar bzip2 gzip xz ca-certificates autoconf automake automake-111 automake-115 gnu-make libtool makedepend pkgconf gdb gcc-49 flex swig git vim gnu-findutils libevent2 libidn nghttp2 pcre pkg openssh ntp bash pipe-viewer zsh system/mozilla-nss screen tmux gnu-grep gnu-patch less curl wget xproto setuptools'

name=$1
if [[ -z "$name" ]]; then
  echo "$0 [-cP] [-d zfsparent] [-p profile] [-o outputfile] <release_name>"
  exit
fi

MPR=`zfs get -H mountpoint $ZROOT | awk '{print $3}'`
if [[ -z "$OUT" ]]; then
  OUT=$MPR/kayak_$name.zfs.bz2
fi

if zfs list $ZROOT/$name@entire > /dev/null 2>&1; then
  zfs rollback -r $ZROOT/$name@entire
  MP=`zfs get -H mountpoint $ZROOT/$name | awk '{print $3}'`
else
  zfs create $ZROOT/$name || fail "zfs create"
  MP=`zfs get -H mountpoint $ZROOT/$name | awk '{print $3}'`
  pkg image-create -F -p $PUBLISHER=$PKGURL $MP || fail "image-create"
  pkg -R $MP set-publisher -p /ws/oi-userland/i386/repo
  pkg -R $MP install osnet-redistributable developer/opensolaris/osnet $USERLAND_PACKAGES || fail 'install'
  zfs snapshot $ZROOT/$name@entire
fi

zfs snapshot $ZROOT/$name@kayak || fail "snap"
zfs send $ZROOT/$name@kayak | $BZIP2 -9 > $OUT || fail "send/compress"
if [[ "$CLEANUP" -eq "1" ]]; then
  zfs destroy $ZROOT/$name@kayak || fail "could not remove snapshot"
  zfs destroy $ZROOT/$name || fail "could not remove zfs filesystem"
fi
