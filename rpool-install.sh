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

RPOOL=${1:-rpool}
ZFS_IMAGE=/root/*.zfs.bz2

echo "Installing from ZFS image $ZFS_IMAGE"

zpool list $RPOOL >& /dev/null
if [[ $? != 0 ]]; then
   echo "Cannot find root pool $RPOOL"
   echo "Press RETURN to exit"
   read
fi

. /usr/lib/kayak/disk_help.sh
. install_help.sh

BuildBE $RPOOL
