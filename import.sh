#!/bin/sh

# Copyright (C) 2022-2023 by Yuri Victorovich. All rights reserved.


##
## import.sh is a script that
## creates the PortsDB SQLite database
## and adds all ports from the ports tree
## specified in the PORTSDIR environment
## variable.
##
##
## Arguments:
## - DB:         (optional) database file to be created (default: ports.sqlite)
## - SQL_FILE:   (optional) file to write the SQL dump from which the database can be recreated
##
## Environment variables:
## - PORTSDIR:   (optional) ports tree to build the database for (default: /usr/ports)
## - SUBDIR:     (optional, DEBUG) choose a subdir in the ports tree, generally produces a broken DB with foreign key violations
##

##
## set strict mode
##

STRICT="set -euo pipefail"
$STRICT

##
## find CODEBASE
##

SCRIPT=$(readlink -f "$0")
CODEBASE=$(dirname "$SCRIPT")

##
## include function libraries and read parameters
##

. $CODEBASE/include/functions.sh
. $CODEBASE/include/functions-import.sh
. $CODEBASE/include/functions-sql.sh
. $CODEBASE/params.sh

##
## read arguments and set defaults
##

DB=${1-} # write the SQLite DB (do not write DB when empty)
SQL_FILE=${2-} # save SQL statements into this file, if set
SQL_FILE_ARG="${SQL_FILE}"

##
## read env variables
##

PORTSDIR=${PORTSDIR:-/usr/ports} # default value
SUBDIR=${SUBDIR-}

##
## global variables
##

PORTSDIR_EFFECTIVE=""
PERFORM_ACTION_WRITE_DB=no
PERFORM_ACTION_WRITE_SQL=no

##
## check dependencies
##

check_dependencies || fail ""

##
## usage
##

usage() {
	$STRICT
	fail "Usage: $0 <db.sqlite> <file.sql> [{sync|async}]"
}

##
## set defaults
##

if [ -z "$DB" -a -z "$SQL_FILE" ]; then
	# no DB or SQL file is supplied, default to ports.sqlite
	DB="ports.sqlite"
fi

##
## what do we do
##

[ -n "$DB" ] && PERFORM_ACTION_WRITE_DB=yes
[ -n "$SQL_FILE_ARG" ] && PERFORM_ACTION_WRITE_FILE=yes

##
## check arguments and required enviroment values
##

if ! is_ports_tree_directory $PORTSDIR; then
	perror "error: the PORTSDIR environment variable should point to a valid ports tree"
	usage
fi

if [ -n "$SUBDIR" ] && ! [ -f "$PORTSDIR/$SUBDIR/Makefile" ]; then
	echo "error: the SUBDIR environment variable is expected to point to a valid subdirectory in the ports tree"
	usage
fi


# create the file for SQL statements that will be written after traversing the ports tree
if [ -z "$SQL_FILE" ]; then
	# generate temporary SQL file if not provided by the user
	SQL_FILE=$(mktemp /tmp/ports.sql.XXXXXX)
fi

##
## adjust values
##

PORTSDIR=$(make_file_path_global $PORTSDIR)
if [ -n "$DB" ]; then
	DB=$(make_file_path_global "$DB")
fi
if [ -n "$SQL_FILE" ]; then
	SQL_FILE=$(make_file_path_global "$SQL_FILE")
fi

##
## save arguments and other values in environment
##

export DB
export SQL_FILE
export CODEBASE
export PORTSDIR

##
## MAIN
##

# announcement
announcement "starting to import"

# explain
explain_action

# initialize
initialize

# traverse
PORTSDIR_EFFECTIVE=$(effective_ports_tree $PORTSDIR)
import $PORTSDIR_EFFECTIVE

# save Git revision of the ports tree
write_ports_tree_revision $PORTSDIR "imported ports tree revision $(ports_tree_get_current_revision $PORTSDIR)"

# finalize
finalize

# remove temp file
delete_temp_files

# status report
status_report

exit 0
