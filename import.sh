#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.


##
## import.sh is a script that
## creates the PortsDB SQLite database
## and adds all ports from the ports tree
## specified in the PORTSDIR environment
## variable.
##
##
## Arguments:
## - DB:         (optional) database file to be created
## - SQL_FILE:   (optional) file to write the SQL dump from which the database can be recreated
## - WRITE_MODE: (optional) 'sync'/'async' are possible values (async is faster)
##
## Environment variables:
## - PORTSDIR:   (optional) ports tree to build the database for (default: /usr/ports)
## - SUBDIR:     (optional, DEBUG) choose a subdir in the ports tree, generally produces a broken DB with foreign key violations
## - SINGLE_PORT (optional, DEBUG) run on one port, generally produces a broken DB with foreign key violations
##

set -e

##
## find CODEBASE
##

SCRIPT=$(readlink -f "$0")
CODEBASE=$(dirname "$SCRIPT")

##
## read arguments
##

DB="$1" # write the SQLite DB
SQL_FILE="$2" # save SQL statements into this file, if set
SQL_FILE_ARG="$SQL_FILE"
WRITE_MODE="$3" # 'sync'/'async'

##
## usage
##

usage() {
	echo "Usage: $0 <db.sqlite> <file.sql> [{sync|async}]"
}

##
## check arguments and required enviroment values
##

if [ -z "$PORTSDIR" ]; then
	PORTSDIR="/usr/ports" # default value
fi

if ! [ -f "$PORTSDIR/Makefile" -a -f "$PORTSDIR/Mk/bsd.port.mk" ]; then
	echo "error: the PORTSDIR environment variable should point to a valid ports tree"
	usage
	exit 1
fi

if [ -n "$SUBDIR" ] && ! [ -f "$PORTSDIR/$SUBDIR/Makefile" ]; then
	echo "error: the SUBDIR environment variable is expected to point to a valid subdirectory in the ports tree"
	usage
	exit 1
fi
if [ -z "$SUBDIR" ]; then
	SUBDIR=""
fi

if [ -z "$SINGLE_PORT" ]; then
	SINGLE_PORT=""
fi

# set defaults
if [ -z "$DB" -a -z "$SQL_FILE" ]; then
	# no DB or SQL file is supplied, default to ports.sqlite
	DB="ports.sqlite"
fi

if [ -z "$WRITE_MODE" ]; then
	WRITE_MODE="async" # default value
fi

case "$WRITE_MODE" in
sync)
	# sync mode: database will be written while traversing the ports tree
	;;
async)
	# async mode: database will be written after traversing the ports tree
	if [ -z "$SQL_FILE" ]; then
		# generate temporary SQL file if not provided by the user
		SQL_FILE_TEMP=$(mktemp /tmp/ports.sql.XXXXXX)
		SQL_FILE=$SQL_FILE_TEMP
	fi
	;;
*)
	usage
	exit 1
	;;
esac

##
## set strict mode
##

set -euo pipefail

##
## check dependency
##

for dep in sqlite3 git; do
	if [ $(echo $(which $dep) | wc -w | sed -e 's| ||g') = 0 ]; then
		echo "error: $dep dependency is missing"
		exit 1
	fi
done

##
## functions
##

. $CODEBASE/functions.sh

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

traverse_ports_tree() {
	if [ -z "$SINGLE_PORT" ]; then # main branch
		(cd $PORTSDIR/$SUBDIR && make describe DESCRIBE_COMMAND="$(describe_command)" -j $(sysctl -n hw.ncpu))
	else # for DEBUG only: single port standalone run
		(cd $PORTSDIR/$SINGLE_PORT && $CODEBASE/add-port-standalone.sh "$DB")
	fi
}

initialize() {
	# create DB if required
	if [ "$WRITE_MODE" = "sync" ]; then
		create_db
	fi

	# begin the SQL file
	if [ -n "$SQL_FILE" ]; then
		(
			echo "--"
			echo "-- SQL dump of the PortsDB"
			echo "-- - PORTSDIR=$PORTSDIR"
			echo "-- - SUBDIR=$SUBDIR"
			echo "-- - SINGLE_PORT=$SINGLE_PORT"
			echo "--"
			echo ""

			echo "-- schema"
			cat $CODEBASE/schema.sql

			echo ""
			echo "-- insert statements"
		) > "$SQL_FILE"
	fi
}

finalize() {
	# end the SQL file
	if [ -n "$SQL_FILE" ]; then
		echo "-- end of file" >> "$SQL_FILE"
	fi

	# create DB from the bulk SQL in the async mode
	if [ -n "$DB" -a "$WRITE_MODE" = "async" ]; then
		# SQL dump to DB
		rm -f "$DB"
		sqlite3 \
			-cmd "PRAGMA journal_mode = MEMORY; PRAGMA synchronous = OFF;" \
			"$DB" \
			< "$SQL_FILE"

		# verify foreign keys
		check_fk_violations
	fi

	# check FKs in the sync mode
	if [ "$WRITE_MODE" = "sync" ]; then
		# verify foreign keys
		check_fk_violations
	fi
}

delete_temp_file() {
	# delete the SQL file if it wasn't requested by the user
	if [ -n "$SQL_FILE_TEMP" ]; then
		rm -f "$SQL_FILE_TEMP"
	fi
}

status_report() {
	echo "PortsDB has finished to import the ports tree at $(date "+%Y-%m-%d %H:%M:%S %Z (%z)") on host $(hostname)"
	if [ -n "$SQL_FILE_ARG" ]; then
		echo "PortsDB created the file with SQL statements to create the DB: $SQL_FILE"
	fi
	if [ -n "$DB" ]; then
		echo "PortsDB created the SQLite database $DB (in $WRITE_MODE mode)"
		echo "... the database has:"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Port;') port records"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM PortFlavor;') flavor records"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Depends;') dependency records"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM GitHub;') GitHub records"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM GitLab;') GitLab records"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Deprecated;') Deprecated records"
		echo "... - $(sqlite3 $DB 'SELECT count(*) FROM Broken;') Broken records"
	fi
}

##
## adjust values
##

if [ -n "$DB" ]; then
	DB=$(make_file_path_global "$DB")
fi
if [ -n "$SQL_FILE" ]; then
	SQL_FILE=$(make_file_path_global "$SQL_FILE")
fi

##
## save arguments in environment
##

export DB
export SQL_FILE
export WRITE_MODE

##
## MAIN
##

# announcement
announcement "starting to import"

# initialize
initialize

# traverse
traverse_ports_tree

# finalize
finalize

# remove temp file
delete_temp_file

# save Git revision of the ports tree
write_ports_tree_revision

# status report
status_report
