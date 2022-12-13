#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.


##
## functions.sh module is a library of functions used by programs
##


##
## set strict mode
##

set -euo pipefail


## general functions

fail() {
	local msg="$1"
	[ -n "$msg" ] && echo $msg >&2
	exit 1
}

perror() {
	local msg="$1"
	echo $msg >&2
}

is_ports_tree_directory() {
	local PD=$1
	[ -f "$PD/Makefile" -a -f "$PD/Mk/bsd.port.mk" -a -d "$PD/.git" ]
}

check_dependencies() {
	local res=0

	for dep in sqlite3 git; do
		if [ $(echo $(which $dep) | wc -w | sed -e 's| ||g') = 0 ]; then
			perror "error: $dep dependency is missing"
			res=1
		fi
	done

	return $res
}

announcement() {
	local action="$1"
	echo "PortsDB is $action the ports tree at $(date "+%Y-%m-%d %H:%M:%S %Z (%z)") on host $(hostname)"
}

make_file_path_global() {
	local path="$1"

	case "$path" in
	/*)
		# do nothing
		echo "$path"
		;;
	*)
		# make path global
		echo "$(pwd)/$path"
		;;
	esac
}

patch_ports_tree() {
	local PD_ORIGINAL="$1"
	local PD_PATCHED

	PD_PATCHED=$(mktemp /tmp/portsdir.XXXXXX)
	rm $PD_PATCHED # we will create the directory instead of this file

	# copy
	$CODEBASE/copy-tree.sh $PD_ORIGINAL $PD_PATCHED
	# patch
	(cd $PD_PATCHED && patch -p 1 --quiet < $CODEBASE/patches/Mk-portsdb.patch >&2) || exit 1

	echo $PD_PATCHED
}

effective_ports_tree() {
	local PD=$1

	if [ $PARAM_PORTSTREE_NEEDS_PATCHING = yes ]; then
		patch_ports_tree $PD
	else
		echo $PD
	fi
}

describe_command() {
	# build DESCRIBE_COMMAND for 'make describe'
	local cmd_args="" # args to supply to add-port.sh
	for name in \
		FLAVOR PKGORIGIN PORTNAME PORTVERSION DISTVERSION DISTVERSIONPREFIX DISTVERSIONSUFFIX PORTREVISION \
		MAINTAINER WWW \
		COMPLETE_OPTIONS_LIST OPTIONS_DEFAULT \
		FLAVORS \
		COMMENT PKGBASE PKGNAME USES \
		BUILD_DEPENDS LIB_DEPENDS RUN_DEPENDS TEST_DEPENDS \
		USE_GITHUB GH_ACCOUNT GH_PROJECT GH_TAGNAME \
		USE_GITLAB GL_SITE GL_ACCOUNT GL_PROJECT GL_COMMIT \
		DEPRECATED EXPIRATION_DATE \
		BROKEN ; \
	do
		if [ $name = "COMMENT" -o $name = "DEPRECATED" -o $name = "BROKEN" ]; then
			cmd_args="$cmd_args '@@@{$name:S/\\@@@/%%DOLLAR%%/g}'"
		else
			cmd_args="$cmd_args '@@@{$name}'"
		fi
	done

	echo "$CODEBASE/add-port.sh '$DB' $cmd_args"
}

## DB-related functions

db_create() {
	rm -f "$DB"
	sqlite3 "$DB" < $CODEBASE/schema.sql
}

db_validate() {
	local DB="$1"
	[ -f "$DB" ] && sqlite3 "$DB" "PRAGMA integrity_check;" > /dev/null 2>&1
}

db_delete_pkgorigin_sql() {
	local pkgorigin=$1
	local SQL=""
	SQL="${SQL}DELETE FROM Broken WHERE PKGORIGIN='$pkgorigin';\n"
	SQL="${SQL}DELETE FROM Deprecated WHERE PKGORIGIN='$pkgorigin';\n"
	SQL="${SQL}DELETE FROM GitLab WHERE PKGORIGIN='$pkgorigin';\n"
	SQL="${SQL}DELETE FROM GitHub WHERE PKGORIGIN='$pkgorigin';\n"
	SQL="${SQL}DELETE FROM Depends WHERE CHILD_PKGORIGIN='$pkgorigin';\n"
	SQL="${SQL}DELETE FROM PortFlavor WHERE PKGORIGIN='$pkgorigin';\n"
	SQL="${SQL}DELETE FROM Port WHERE PKGORIGIN='$pkgorigin';\n"
	printf "$SQL"
}

db_read_last_ports_tree_revision() {
	sqlite3 "$DB" "SELECT GIT_HASH FROM PortsTreeRevision ORDER BY UPDATE_TIMESTAMP DESC LIMIT 1;"
}

db_check_fk_violations() {
	local violations

	violations=$(sqlite3 "$DB" "PRAGMA foreign_key_check;")
	if [ -n "$violations" ]; then
		echo "warning: database has $(sqlite3 "$DB" "PRAGMA foreign_key_check;" | wc -l | sed -e 's| ||g') foreign key violation(s)"
		echo "info: foreign key violations are most likely due to missing flavors in some Python ports, due"
	fi
}

db_print_stats() {
	local DB="$1"
	echo "... the database has:"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Port;') port records"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM PortFlavor;') flavor records"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Depends;') dependency records"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM GitHub;') GitHub records"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM GitLab;') GitLab records"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Deprecated;') Deprecated records"
	echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Broken;') Broken records"
}

## ports tree revision handling functions

ports_tree_get_current_revision() {
	local PD=$1

	(cd $PD && git rev-parse HEAD)
}

ports_tree_traverse() {
	local PD=$1
	local SUBDIR=$2

	(cd $PD && PORTSDIR=$PD make -I $PD -C $PD/$SUBDIR describe DESCRIBE_COMMAND="$(describe_command)" -j $(sysctl -n hw.ncpu))
}

save_ports_tree_revision() {
	local revision=$1
	local comment="$2"
	run_SQL "INSERT into PortsTreeRevision(UPDATE_TIMESTAMP, GIT_HASH, COMMENT) VALUES(DATETIME('now'), '$revision', '$comment');"
}

write_ports_tree_revision() {
	local PD=$1
	local comment="$2"
	local revision

	revision=$(ports_tree_get_current_revision $PD)
	save_ports_tree_revision $revision "$comment"
}


## git-related

git_diff_revisions_to_pkgorigin() { # returns list of changed pkgorigins between two given revisions
	local PD=$1
	local rev1="$2"
	local rev2="$3"

	local subdir_term=""
	[ -n "$SUBDIR" -a $SUBDIR != . ] && subdir_term="-- $SUBDIR"

	(cd $PD &&
		git log --pretty=format: --name-only $rev1..$rev2 $subdir_term |
		grep -E "^[^/]+/[^/]+/.*" |
		sed -E "s|^([^/]+/[^/]+)/.*|\1|" |
		sort |
		uniq
	)
}

## SQL file handling

sql_file_begin() {
	local sql_file="$1"
	local with_schema="$2"

	(
		echo "--"
		echo "-- SQL dump of the PortsDB"
		echo "-- - PORTSDIR=$PORTSDIR"
		echo "-- - SUBDIR=$SUBDIR"
		echo "--"
		echo ""

		if [ $with_schema = 1 ]; then
			echo "-- schema"
			cat $CODEBASE/schema.sql
			echo ""
		fi

		echo "-- insert statements"
	) > "$sql_file"
}

## temporary file handling

delete_temp_files() {
	local tmp_files=""

	if [ $PORTSDIR_EFFECTIVE != $PORTSDIR ]; then
		tmp_files="$tmp_files $PORTSDIR_EFFECTIVE"
	fi
	if [ -z "$SQL_FILE_ARG" -a -n "$SQL_FILE" ]; then
		tmp_files="$tmp_files $SQL_FILE"
	fi

	for f in $tmp_files; do
		rm -rf $f
	done
}
