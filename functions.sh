#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.

##
## functions.sh module is a library of functions used by programs
##

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
