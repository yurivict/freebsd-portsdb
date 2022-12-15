#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.


##
## update.sh is a script that
## updates the PortsDB SQLite database
## and adds all ports from the ports tree
## specified in the PORTSDIR environment
## variable.
##
##
## Arguments:
## - DB:         (optional) database file to be updated (default: ports.sqlite)
## - SQL_FILE:   (optional) file to write the SQL dump from which the database can be recreated
##
## Environment variables:
## - PORTSDIR:   (optional) ports tree to build the database for (default: /usr/ports)
## - SUBDIR:     (optional, DEBUG) choose a subdir in the ports tree, generally produces a broken DB with foreign key violations
##

##
## set strict mode
##

set -euo pipefail

##
## find CODEBASE
##

SCRIPT=$(readlink -f "$0")
CODEBASE=$(dirname "$SCRIPT")

##
## include function libraries and read parameters
##

. $CODEBASE/include/functions.sh
. $CODEBASE/include/functions-update.sh
. $CODEBASE/include/functions-sql.sh
. $CODEBASE/params.sh

##
## read arguments and set defaults
##

DB=${1:-ports.sqlite} # write the SQLite DB
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
UPDATED=no
UPDATED_PKGORIGIN_COUNT=0
UPDATED_FROM_REVISION=""
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
	fail "Usage: $0 <db.sqlite> <file.sql> [{sync|async}]"
}

##
## what do we do
##

if [ -z "$SQL_FILE_ARG" ]; then # update.sh only writes either DB or SQL, but not both
	PERFORM_ACTION_WRITE_DB=yes
else
	PERFORM_ACTION_WRITE_FILE=yes
fi

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

# database will be written after traversing the ports tree
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
SQL_FILE=$(make_file_path_global "$SQL_FILE")

##
## save arguments and other values in environment
##

export DB
export SQL_FILE
export CODEBASE

##
## MAIN
##

# announcement and action explanation
announcement "starting to update"
explain_action

# validate DB
db_validate "$DB" || fail "error: DB file '$DB' doesn't exist or isn't a valid SQLite database file"

# initialize
initialize

# update
PORTSDIR_EFFECTIVE=$(effective_ports_tree $PORTSDIR)
update $PORTSDIR_EFFECTIVE "$SUBDIR"

# save Git revision of the ports tree
[ $UPDATED = yes ] && write_ports_tree_revision $PORTSDIR "updated ports tree for revisions $UPDATED_FROM_REVISION..$(ports_tree_get_current_revision $PORTSDIR)"

# finalize
finalize

# remove temp file
delete_temp_files

# status report
[ $UPDATED = yes ] && status_report

exit 0
