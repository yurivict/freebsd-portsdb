#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.

set -euo pipefail


PORTSDIR=$1
NEW_TREE=$2

mkdir $NEW_TREE
for d in $(cd $PORTSDIR && ls); do
	if [ -d "$PORTSDIR/$d" -a -f "$PORTSDIR/$d/Makefile" ]; then
		ln -s $PORTSDIR/$d $NEW_TREE/$d
	fi
done

ln -s $PORTSDIR/Makefile $NEW_TREE/Makefile
cp -r $PORTSDIR/Mk $NEW_TREE/Mk
ln -s $PORTSDIR/.git $NEW_TREE/.git
