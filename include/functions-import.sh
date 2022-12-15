#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.

##
## library of functions for the import module
##

set -euo pipefail


explain_action() {
	echo "actions that will be performed:"
	if [ $PERFORM_ACTION_WRITE_DB = yes ]; then
		echo " - import the ports tree into the database $DB"
	fi
	if [ $PERFORM_ACTION_WRITE_SQL = yes ]; then
		echo " - import the ports tree into the SQL dump file $SQL_FILE_ARG"
	fi
	if [ -n "$SUBDIR" ]; then
		echo " (!) only the subdirectory '$SUBDIR' of the ports tree will be imported"
	fi
}

initialize() {
	# begin the SQL file
	sql_file_begin "$SQL_FILE" 1 # with schema
}

import() {
	local PD=$1
	local NOBUF="stdbuf -i0 -o0 -e0"

	ports_tree_traverse $PD "$SUBDIR" 2>&1 |
		$NOBUF grep "^===> " |
		$NOBUF sed -e 's|===> ||' |
		$NOBUF $CODEBASE/util/number-lines.sh |
		$NOBUF $CODEBASE/util/squeeze-log-into-line.sh
}

finalize() {
	# end the SQL file
	cat $CODEBASE/sql/fix-default-parent-flavor.sql >> "$SQL_FILE"
	echo "-- end of file" >> "$SQL_FILE"

	# create DB from the bulk SQL
	if [ $PERFORM_ACTION_WRITE_DB = yes ]; then
		# SQL dump to DB
		rm -f "$DB"
		sqlite3 \
			-cmd "PRAGMA journal_mode = MEMORY; PRAGMA synchronous = OFF;" \
			"$DB" \
			< "$SQL_FILE"

		# verify foreign keys
		db_check_fk_violations
	fi
}

status_report() {
	echo "PortsDB has finished to import the ports tree at $(date "+%Y-%m-%d %H:%M:%S %Z (%z)") on host $(hostname)"

	if [ $PERFORM_ACTION_WRITE_DB = yes ]; then
		echo "- PortsDB created the SQLite database $DB"
		db_print_stats $DB
	fi
	[ $PERFORM_ACTION_WRITE_SQL = yes ] &&
		echo "- PortsDB created the file with SQL statements to create the DB: $SQL_FILE"
	return 0
}

