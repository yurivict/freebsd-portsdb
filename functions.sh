#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.


##
## set strict mode
##

set -euo pipefail

##
## functions.sh module is a library of functions used by programs
##

is_ports_tree_directory() {
	local PD="$1"
	[ -f "$PD/Makefile" -a -f "$PD/Mk/bsd.port.mk" -a -d "$PD/.git" ]
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

describe_command() {
	# build DESCRIBE_COMMAND for 'make describe'
	local cmd_args="" # args to supply to add-port.sh
	for name in \
		FLAVOR PKGORIGIN PORTNAME PORTVERSION DISTVERSION DISTVERSIONPREFIX DISTVERSIONSUFFIX PORTREVISION \
		MAINTAINER WWW \
		COMPLETE_OPTIONS_LIST OPTIONS_DEFAULT \
		FLAVORS \
		COMMENT PKGBASE PKGNAME USES \
		BUILD_DEPENDS RUN_DEPENDS TEST_DEPENDS \
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

create_db() {
	rm -f "$DB"
	sqlite3 "$DB" < $CODEBASE/schema.sql
}

check_fk_violations() {
	local violations=$(sqlite3 "$DB" "PRAGMA foreign_key_check;")
	if [ -n "$violations" ]; then
		echo "warning: database has $(sqlite3 "$DB" "PRAGMA foreign_key_check;" | wc -l | sed -e 's| ||g') foreign key violation(s)"
		echo "info: foreign key violations are most likely due to missing flavors in some Python ports, due"
	fi
}

get_current_ports_tree_revision() {
	(cd $PORTSDIR && git rev-parse HEAD)
}

save_ports_tree_revision() {
	local revision=$1
	sqlite3 "$DB" "INSERT into PortsTreeRevision(UPDATE_TIMESTAMP, GIT_HASH) VALUES(DATETIME('now'), '$revision');"
}

write_ports_tree_revision() {
	local revision
	revision=$(get_current_ports_tree_revision)
	save_ports_tree_revision $revision
}
