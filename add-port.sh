#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.


set -e

##
## functions
##

log() {
	#echo "add-port.sh: $1"
}

wrap_nullable_string() {
	if [ -z "$1" ]; then
		echo "null"
	else
		echo "'$1'"
	fi
}
wrap_non_nullable_string() {
	echo "'$1'"
}
wrap_nullable_integer() {
	if [ -z "$1" ]; then
		echo "null"
	else
		echo "'$1'"
	fi
}
wrap_non_nullable_integer() {
	echo $1
}
list_begins_with() {
	local small="$1"
	local large="$2"
	local pattern="$small "

	if [ "$small" = "$large" ]; then
		echo "YES"
		return
	fi

	case "$large" in
		$pattern*)
			echo "YES"
			;;
		*)
			echo "NO"
			;;
	esac
}
escape_special_chars() {
	echo "$1" | sed -e "s|'|''|g"
}
expand_dollar_sign() {
	echo "$1" | sed -e "s|%%DOLLAR%%|$|g"
}

##
## read supplied arguments
##

for name in DB \
	FLAVOR PKGORIGIN PORTNAME PORTVERSION DISTVERSION DISTVERSIONPREFIX DISTVERSIONSUFFIX PORTREVISION \
	MAINTAINER WWW FLAVORS COMMENT PKGNAME PKGBASE \
	BUILD_DEPENDS RUN_DEPENDS TEST_DEPENDS \
       	USE_GITHUB GH_ACCOUNT GH_PROJECT GH_TAGNAME \
	USE_GITLAB GL_SITE GL_ACCOUNT GL_PROJECT GL_COMMIT ; \
do
	eval "$name=\"$1\""
	shift
done

##
## wrap argument values
##

PKGORIGINw=$(wrap_non_nullable_string "$PKGORIGIN")
PORTNAMEw=$(wrap_non_nullable_string "$PORTNAME")
PORTVERSIONw=$(wrap_non_nullable_string "$PORTVERSION")
DISTVERSIONw=$(wrap_non_nullable_string "$DISTVERSION")
DISTVERSIONPREFIXw=$(wrap_nullable_string "$DISTVERSIONPREFIX")
DISTVERSIONSUFFIXw=$(wrap_nullable_string "$DISTVERSIONSUFFIX")
PORTREVISIONw=$(wrap_nullable_integer "$PORTREVISION")
MAINTAINERw=$(wrap_non_nullable_string "$MAINTAINER")
WWWw=$(wrap_non_nullable_string "$WWW")
FLAVORSw=$(wrap_nullable_string "$FLAVORS")
FLAVORw=$(wrap_non_nullable_string "$FLAVOR")
COMMENTw=$(expand_dollar_sign "$(wrap_non_nullable_string "$(escape_special_chars "$COMMENT")")")
PKGNAMEw=$(wrap_non_nullable_string "$PKGNAME")
PKGBASEw=$(wrap_non_nullable_string "$PKGBASE")
USE_GITHUBw=$(wrap_non_nullable_string "$USE_GITHUB")
GH_ACCOUNTw=$(wrap_non_nullable_string "$GH_ACCOUNT")
GH_PROJECTw=$(wrap_non_nullable_string "$GH_PROJECT")
GH_TAGNAMEw=$(wrap_non_nullable_string "$GH_TAGNAME")

USE_GITLABw=$(wrap_non_nullable_string "$USE_GITLAB")
GL_SITEw=$(wrap_non_nullable_string "$GL_SITE")
GL_ACCOUNTw=$(wrap_non_nullable_string "$GL_ACCOUNT")
GL_PROJECTw=$(wrap_non_nullable_string "$GL_PROJECT")
GL_COMMITw=$(wrap_nullable_string "$GL_COMMIT")

##
## DB functions
##

run_SQL() {
	local SQL="$1"

	# execute synchronously
	if [ -n "$DB" -a "$WRITE_MODE" = "sync" ]; then
		sqlite3 -cmd '.timeout 50000' $DB "$SQL"
	fi

	# save SQL statements into a file
	if [ -n "$SQL_FILE" ]; then
		echo "$SQL;" >> "$SQL_FILE"
	fi
}
insert_port() {
	run_SQL "INSERT INTO Port(PKGORIGIN,PORTNAME,PORTVERSION,DISTVERSION,DISTVERSIONPREFIX,DISTVERSIONSUFFIX,PORTREVISION,MAINTAINER,WWW,FLAVORS) VALUES ($PKGORIGINw,$PORTNAMEw,$PORTVERSIONw,$DISTVERSIONw,$DISTVERSIONPREFIXw,$DISTVERSIONSUFFIXw,$PORTREVISIONw,$MAINTAINERw,$WWWw,$FLAVORSw)"
}
insert_flavor() {
	run_SQL "INSERT INTO PortFlavor(PKGORIGIN,FLAVOR,COMMENT,PKGBASE,PKGNAME) VALUES ($PKGORIGINw,$FLAVORw,$COMMENTw,$PKGBASEw,$PKGNAMEw)"
}
insert_dependencies() {
	local PKGORIGIN="$1"
	local FLAVOR="$2"
	local DEPENDS="$3"
	local KIND="$4"

	local CHILD_PKGORIGINw=$(wrap_non_nullable_string "$PKGORIGIN")
	local CHILD_FLAVORw=$(wrap_nullable_string "$FLAVOR")

	for DEP in $DEPENDS; do
		local PARENT_PKGORIGIN=""
		local PARENT_FLAVOR=""
		for D in $(echo $DEP | sed -e 's|.*:||; s|@| |'); do
			if [ -z "$PARENT_PKGORIGIN" ]; then
				PARENT_PKGORIGIN=$D
			else
				PARENT_FLAVOR=$D
			fi
		done

		local PARENT_PKGORIGINw=$(wrap_non_nullable_string "$PARENT_PKGORIGIN")
		local PARENT_FLAVORw=$(wrap_nullable_string "$PARENT_FLAVOR")

		run_SQL "INSERT OR IGNORE INTO Depends(PARENT_PKGORIGIN,PARENT_FLAVOR,CHILD_PKGORIGIN,CHILD_FLAVOR,KIND) VALUES($PARENT_PKGORIGINw,$PARENT_FLAVORw,$CHILD_PKGORIGINw,$CHILD_FLAVORw,'$KIND')"
	done
}
insert_github() {
	run_SQL "INSERT INTO GitHub(PKGORIGIN, FLAVOR, USE_GITHUB, GH_ACCOUNT, GH_PROJECT, GH_TAGNAME) VALUES($PKGORIGINw,$FLAVORw,$USE_GITHUBw,$GH_ACCOUNTw,$GH_PROJECTw,$GH_TAGNAMEw)"
}
insert_gitlab() {
	run_SQL "INSERT INTO GitLab(PKGORIGIN, FLAVOR, USE_GITLAB, GL_SITE, GL_ACCOUNT, GL_PROJECT, GL_COMMIT) VALUES($PKGORIGINw,$FLAVORw,$USE_GITLABw,$GL_SITEw,$GL_ACCOUNTw,$GL_PROJECTw,$GL_COMMITw)"
}

##
## MAIN: insert records into the DB
##

if [ -z "$FLAVORS" -o $(list_begins_with "$FLAVOR" "$FLAVORS") = "YES" ]; then # no flavors or default flavor
	log "adding Port record for $PKGORIGIN (FLAVOR=$FLAVOR FLAVORS=$FLAVORS)"
	run_SQL "INSERT INTO Port(PKGORIGIN,PORTNAME,PORTVERSION,DISTVERSION,DISTVERSIONPREFIX,DISTVERSIONSUFFIX,PORTREVISION,MAINTAINER,WWW,FLAVORS) VALUES ($PKGORIGINw,$PORTNAMEw,$PORTVERSIONw,$DISTVERSIONw,$DISTVERSIONPREFIXw,$DISTVERSIONSUFFIXw,$PORTREVISIONw,$MAINTAINERw,$WWWw,$FLAVORSw)"
	insert_flavor
else # subsequent flavors
	log "adding subsequent PortFlavor record for $PKGORIGIN: FLAVOR=$FLAVOR FLAVORS=$FLAVORS PKGBASE=$PKGBASE PKGNAME=$PKGNAME"
	insert_flavor
fi

# add dependency records
insert_dependencies $PKGORIGIN "$FLAVOR" "$BUILD_DEPENDS" B
insert_dependencies $PKGORIGIN "$FLAVOR" "$RUN_DEPENDS"   R
insert_dependencies $PKGORIGIN "$FLAVOR" "$TEST_DEPENDS"  T

# add GitHub record
if [ -n "$USE_GITHUB" ]; then
	insert_github
fi

# add GitLab record
if [ -n "$USE_GITLAB" ]; then
	insert_gitlab
fi
