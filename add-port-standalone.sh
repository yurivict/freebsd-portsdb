#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.

##
## add-port-standalone.sh is a script that
## runs standalone in a single port directory.
## It adds one port with its flavors to the DB.
## It is provided **for test purposes only**,
## for one to examine a single port.
##

set -e

##
## args
##

DB=$1
if [ -z "$DB" ]; then
	echo "Usage: $0 <db.sqlite>"
	exit 1
fi

##
## find CODEBASE
##

SCRIPT=$(readlink -f "$0")
CODEBASE=$(dirname "$SCRIPT")

##
## all needed variables
##

ALL_VARS="PKGORIGIN PORTNAME PORTVERSION DISTVERSION DISTVERSIONPREFIX DISTVERSIONSUFFIX PORTREVISION PKGNAME MAINTAINER WWW COMMENT PKGBASE BUILD_DEPENDS LIB_DEPENDS RUN_DEPENDS TEST_DEPENDS"

# get values
for name in FLAVORS; do
	eval "$name='$(make -V $name)'"
done;


# pass values to add-port.sh
if [ -z "${FLAVORS}" ]; then # no flavors
	# get values
	for name in $ALL_VARS; do
		#eval "$name=\"$(make -V $name)\""
		eval "$name=\$(make -V \$name:S/"\\\`"/"\\\\\\\`"/g:S/"\\\""/"\\\\\\\""/g)" # WORKS!
	done;

	# add port
	$CODEBASE/add-port.sh $DB \
		"" "$PKGORIGIN" "$PORTNAME" "$PORTVERSION" "$DISTVERSION" "$DISTVERSIONPREFIX" "$DISTVERSIONSUFFIX" "$PORTREVISION" "$PKGNAME" "$MAINTAINER" "$WWW" "$FLAVORS" \
		"$COMMENT" "$PKGBASE" \
		"$BUILD_DEPENDS" "$LIB_DEPENDS" "$RUN_DEPENDS" "$TEST_DEPENDS"
else
	for FLAVOR in ${FLAVORS}; do
		# get values
		for name in $ALL_VARS; do
			eval "$name=\"$(FLAVOR=$FLAVOR make -V $name)\""
		done;

		# add port and flavor
		$CODEBASE/add-port.sh $DB \
			"$FLAVOR" "$PKGORIGIN" "$PORTNAME" "$PORTVERSION" "$DISTVERSION" "$DISTVERSIONPREFIX" "$DISTVERSIONSUFFIX" "$PORTREVISION" "$PKGNAME" "$MAINTAINER" "$WWW" "$FLAVORS" \
			"$COMMENT" "$PKGBASE" \
			"$BUILD_DEPENDS" "$LIB_DEPENDS" "$RUN_DEPENDS" "$TEST_DEPENDS"
	done
fi
