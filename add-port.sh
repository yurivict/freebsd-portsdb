#!/bin/sh

# Copyright (C) 2022-2023 by Yuri Victorovich. All rights reserved.


##
## set strict mode
##

STRICT="set -euo pipefail"
$STRICT

##
## functions
##

. $CODEBASE/include/functions-sql.sh

log() {
	$STRICT
	#echo "add-port.sh: $1"
}

wrap_nullable_string() {
	$STRICT
	if [ -z "$1" ]; then
		echo "null"
	else
		echo "'$1'"
	fi
}
wrap_non_nullable_string() {
	$STRICT
	echo "'$1'"
}
wrap_nullable_integer() {
	$STRICT
	if [ -z "$1" ]; then
		echo "null"
	else
		echo "$1"
	fi
}
wrap_non_nullable_integer() {
	$STRICT
	echo $1
}
list_begins_with() {
	$STRICT
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
	$STRICT
	echo "$1" | sed -e "s|'|''|g"
}
expand_dollar_sign() {
	$STRICT
	echo "$1" | sed -e "s|%%DOLLAR%%|$|g"
}
normalize_makefile() {
	$STRICT
	# the filter chooses makefiles (1) only in the ports tree (2) not in the current port's directory
	echo $1 | xargs realpath | (grep "^$PORTSDIR" || true) | sed -e "s|^$PORTSDIR/||" | (grep -v "^$PKGORIGIN/" || true)
}

##
## read supplied arguments
##

for name in DB \
	FLAVOR PKGORIGIN PORTNAME PORTVERSION DISTVERSION DISTVERSIONPREFIX DISTVERSIONSUFFIX PORTREVISION \
	PORTEPOCH CATEGORIES \
	MAINTAINER WWW \
	CPE_STR \
	COMPLETE_OPTIONS_LIST OPTIONS_DEFAULT \
	FLAVORS \
	COMMENT PKGBASE PKGNAME PKGNAMESUFFIX USES \
	PKG_DEPENDS FETCH_DEPENDS EXTRACT_DEPENDS PATCH_DEPENDS BUILD_DEPENDS LIB_DEPENDS RUN_DEPENDS TEST_DEPENDS \
       	USE_GITHUB GH_ACCOUNT GH_PROJECT GH_TAGNAME \
	USE_GITLAB GL_SITE GL_ACCOUNT GL_PROJECT GL_COMMIT \
	DEPRECATED EXPIRATION_DATE \
	BROKEN \
	MAKEFILES ; \
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
PORTEPOCHw=$(wrap_nullable_integer "$PORTEPOCH")
CATEGORIESw=$(wrap_non_nullable_string "$CATEGORIES")
MAINTAINERw=$(wrap_non_nullable_string "$MAINTAINER")
WWWw=$(wrap_non_nullable_string "$WWW")
CPE_STRw=$(expand_dollar_sign "$(wrap_nullable_string "$(escape_special_chars "$CPE_STR")")")
COMPLETE_OPTIONS_LISTw=$(wrap_nullable_string "$COMPLETE_OPTIONS_LIST")
OPTIONS_DEFAULTw=$(wrap_nullable_string "$OPTIONS_DEFAULT")
FLAVORSw=$(wrap_nullable_string "$FLAVORS")
FLAVORw=$(wrap_non_nullable_string "$FLAVOR")
COMMENTw=$(expand_dollar_sign "$(wrap_non_nullable_string "$(escape_special_chars "$COMMENT")")")
PKGBASEw=$(wrap_non_nullable_string "$PKGBASE")
PKGNAMEw=$(wrap_non_nullable_string "$PKGNAME")
PKGNAMESUFFIXw=$(wrap_nullable_string "$PKGNAMESUFFIX")
USESw=$(wrap_nullable_string "$USES")
USE_GITHUBw=$(wrap_non_nullable_string "$USE_GITHUB")
GH_ACCOUNTw=$(wrap_non_nullable_string "$GH_ACCOUNT")
GH_PROJECTw=$(wrap_non_nullable_string "$GH_PROJECT")
GH_TAGNAMEw=$(wrap_non_nullable_string "$GH_TAGNAME")
USE_GITLABw=$(wrap_non_nullable_string "$USE_GITLAB")
GL_SITEw=$(wrap_non_nullable_string "$GL_SITE")
GL_ACCOUNTw=$(wrap_non_nullable_string "$GL_ACCOUNT")
GL_PROJECTw=$(wrap_non_nullable_string "$GL_PROJECT")
GL_COMMITw=$(wrap_nullable_string "$GL_COMMIT")
DEPRECATEDw=$(expand_dollar_sign "$(wrap_non_nullable_string "$(escape_special_chars "$DEPRECATED")")")
EXPIRATION_DATEw=$(wrap_nullable_string "$EXPIRATION_DATE")
BROKENw=$(expand_dollar_sign "$(wrap_non_nullable_string "$(escape_special_chars "$BROKEN")")")

##
## DB functions
##

insert_port() {
	$STRICT
	run_SQL "INSERT INTO Port(PKGORIGIN,PORTNAME,PORTVERSION,DISTVERSION,DISTVERSIONPREFIX,DISTVERSIONSUFFIX,PORTREVISION,PORTEPOCH,CATEGORIES,MAINTAINER,WWW,CPE_STR,COMPLETE_OPTIONS_LIST,OPTIONS_DEFAULT,FLAVORS) VALUES ($PKGORIGINw,$PORTNAMEw,$PORTVERSIONw,$DISTVERSIONw,$DISTVERSIONPREFIXw,$DISTVERSIONSUFFIXw,$PORTREVISIONw,$PORTEPOCHw,$CATEGORIESw,$MAINTAINERw,$WWWw,$CPE_STRw,$COMPLETE_OPTIONS_LISTw,$OPTIONS_DEFAULTw,$FLAVORSw)"
}
insert_flavor() {
	$STRICT
	run_SQL "INSERT INTO PortFlavor(PKGORIGIN,FLAVOR,COMMENT,PKGBASE,PKGNAME,PKGNAMESUFFIX,USES) VALUES ($PKGORIGINw,$FLAVORw,$COMMENTw,$PKGBASEw,$PKGNAMEw,$PKGNAMESUFFIXw,$USESw)"
}
insert_dependencies() {
	$STRICT
	local PKGORIGIN="$1"
	local FLAVOR="$2"
	local DEPENDS="$3"
	local KIND="$4"

	local CHILD_PKGORIGINw=$(wrap_non_nullable_string "$PKGORIGIN")
	local CHILD_FLAVORw=$(wrap_non_nullable_string "$FLAVOR")

	for DEP in $DEPENDS; do
		local PARENT_PKGORIGIN=""
		local PARENT_FLAVOR=""
                local PARENT_PHASE=""

		# parse dependency expression into shell expression
		# the format is ({pkg_ver_spec}|{exe}|{shlib}):{pkgorigin}(|:{parent_stage})(|@{parent_flavor}) - it has 4 parts, out of which 1 part is ignored, and 2 are optional
		local expression
                expression=$(echo $DEP | gsed -E 's/([^:@]+):([^:@]+)(|:([a-z]+))(|@([a-zA-Z0-9_]+))$/PARENT_PKGORIGIN=\2;PARENT_FLAVOR=\6;PARENT_PHASE=\4/')
		# expression wouldn't be equal to $DEP in case the above regex would fail to match the string, and the next line would fail

		# evaluate shell expression
		eval $expression

		# wrap values
		local PARENT_PKGORIGINw=$(wrap_non_nullable_string "$PARENT_PKGORIGIN")
		local PARENT_FLAVORw=$(wrap_non_nullable_string "$PARENT_FLAVOR")
		local PARENT_PHASEw=$(wrap_nullable_string "$PARENT_PHASE")

		# write into DB
		run_SQL "INSERT OR IGNORE INTO Depends(PARENT_PKGORIGIN,PARENT_FLAVOR,PARENT_PHASE,CHILD_PKGORIGIN,CHILD_FLAVOR,KIND) VALUES($PARENT_PKGORIGINw,$PARENT_FLAVORw,$PARENT_PHASEw,$CHILD_PKGORIGINw,$CHILD_FLAVORw,'$KIND')"
	done
}
insert_github() {
	$STRICT
	run_SQL "INSERT INTO GitHub(PKGORIGIN, FLAVOR, USE_GITHUB, GH_ACCOUNT, GH_PROJECT, GH_TAGNAME) VALUES($PKGORIGINw,$FLAVORw,$USE_GITHUBw,$GH_ACCOUNTw,$GH_PROJECTw,$GH_TAGNAMEw)"
}
insert_gitlab() {
	$STRICT
	run_SQL "INSERT INTO GitLab(PKGORIGIN, FLAVOR, USE_GITLAB, GL_SITE, GL_ACCOUNT, GL_PROJECT, GL_COMMIT) VALUES($PKGORIGINw,$FLAVORw,$USE_GITLABw,$GL_SITEw,$GL_ACCOUNTw,$GL_PROJECTw,$GL_COMMITw)"
}
insert_deprecated() {
	$STRICT
	run_SQL "INSERT INTO Deprecated(PKGORIGIN, FLAVOR, DEPRECATED, EXPIRATION_DATE) VALUES($PKGORIGINw,$FLAVORw,$DEPRECATEDw,$EXPIRATION_DATEw)"
}
insert_broken() {
	$STRICT
	run_SQL "INSERT INTO Broken(PKGORIGIN, FLAVOR, BROKEN) VALUES($PKGORIGINw,$FLAVORw,$BROKENw)"
}
insert_makefile_dependencies() {
	$STRICT
	for m in $MAKEFILES; do
		if [ $m != "Makefile" ]; then
			m=$(cd $PORTSDIR/$PKGORIGIN && normalize_makefile $m)
			if [ -n "$m" ]; then
				run_SQL "INSERT INTO MakefileDependencies(PKGORIGIN, FLAVOR, MAKEFILE) VALUES($PKGORIGINw,$FLAVORw,$(wrap_non_nullable_string $m))"
			fi
		fi
	done
}

##
## MAIN: insert records into the DB
##

if [ -z "$FLAVORS" -o $(list_begins_with "$FLAVOR" "$FLAVORS") = "YES" ]; then # no flavors or default flavor
	log "adding Port record for $PKGORIGIN (FLAVOR=$FLAVOR FLAVORS=$FLAVORS)"
	insert_port
	insert_flavor
else # subsequent flavors
	log "adding subsequent PortFlavor record for $PKGORIGIN: FLAVOR=$FLAVOR FLAVORS=$FLAVORS PKGBASE=$PKGBASE PKGNAME=$PKGNAME PKGNAMESUFFIX=$PKGNAMESUFFIX"
	insert_flavor
fi

# add dependency records
insert_dependencies $PKGORIGIN "$FLAVOR" "$PKG_DEPENDS"     G
insert_dependencies $PKGORIGIN "$FLAVOR" "$FETCH_DEPENDS"   F
insert_dependencies $PKGORIGIN "$FLAVOR" "$EXTRACT_DEPENDS" E
insert_dependencies $PKGORIGIN "$FLAVOR" "$PATCH_DEPENDS"   P
insert_dependencies $PKGORIGIN "$FLAVOR" "$BUILD_DEPENDS"   B
insert_dependencies $PKGORIGIN "$FLAVOR" "$LIB_DEPENDS"     L
insert_dependencies $PKGORIGIN "$FLAVOR" "$RUN_DEPENDS"     R
insert_dependencies $PKGORIGIN "$FLAVOR" "$TEST_DEPENDS"    T

# add GitHub record
if [ -n "$USE_GITHUB" ]; then
	insert_github
fi

# add GitLab record
if [ -n "$USE_GITLAB" ]; then
	insert_gitlab
fi

# add Deprecated record
if [ -n "$DEPRECATED" ]; then
	insert_deprecated
fi

# add Broken record
if [ -n "$BROKEN" ]; then
	insert_broken
fi

insert_makefile_dependencies
