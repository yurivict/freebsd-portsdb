#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.

##
## library of functions for the import module
##

set -euo pipefail


explain_action() {
	echo "actions that will be performed:"
	if [ $PERFORM_ACTION_WRITE_DB = yes ]; then
		echo " - update database $DB with ports tree updates"
	fi
	if [ $PERFORM_ACTION_WRITE_SQL = yes ]; then
		echo " - import the ports tree updates into the SQL dump file $SQL_FILE_ARG"
	fi
	if [ -n "$SUBDIR" ]; then
		echo " (!) updated only for the subdirectory '$SUBDIR' of the ports tree will be processed"
	fi
}

initialize() {
	# begin the SQL file
	sql_file_begin "$SQL_FILE" 0 # no schema
}

update() {
	local PD=$1
	local SUBDIR=$1

	local old_revision new_revision pkgorigins
	old_revision=$(db_read_last_ports_tree_revision)
	new_revision=$(ports_tree_get_current_revision $PD)
	if [ -z "$old_revision" -o -z "$new_revision" ]; then
		echo "invalid revision" # this should never happen
		exit 1
	fi

	# any updates?
	if [ $new_revision = $old_revision ]; then
		echo "no updates were found (ports tree revision is $new_revision) - nothing to do"
		return
	fi

	# find all pkgorigins in delta
	pkgorigins="$(git_diff_revisions_to_pkgorigin $PD $old_revision $new_revision)"

	# limit how many pkgorigins we can do
	local num=1
	for po in $pkgorigins; do
		echo "pkgorigin[$num]=$po"
		num=$((num+1))
		if [ $num = $PARAM_PORTSDB_UPDATE_LIMIT ]; then
			echo "TODO too many ($num) pkgorigins are updated - need to run full import"
		fi
	done
	num=$((num-1))

	# update
	local n=1
	for po in $pkgorigins; do
		# delete previous records
		run_SQL "$(db_delete_pkgorigin_sql $po)"
		# insert new records
		if [ -d $PD/$po ]; then # otherwise this pkgorigin was removed
			echo "updating pkgorigin[$n of $num]=$po"
			ports_tree_traverse $PD $po > /dev/null 2>&1 || fail "failed to update of the pkgorigin[$n]=$po ... exiting"
			n=$((n+1))
		fi
		# count
		UPDATED_PKGORIGIN_COUNT=$((UPDATED_PKGORIGIN_COUNT+1))
	done

	# set global value
	UPDATED=yes
	UPDATED_FROM_REVISION=$old_revision
}

finalize() {
	# end the SQL file
	echo "-- end of file" >> "$SQL_FILE"

	# create DB from the bulk SQL if SQL wasn't requested by the user
	if [ $PERFORM_ACTION_WRITE_DB = yes -a $UPDATED = yes ]; then
		# SQL dump to DB
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

	[ $UPDATED = yes ] && echo "PortsDB has finished to update the ports tree at $(date "+%Y-%m-%d %H:%M:%S %Z (%z)") on host $(hostname)"
	if [ $PERFORM_ACTION_WRITE_DB = yes ]; then
		echo " - PortsDB updated $UPDATED_PKGORIGIN_COUNT pkgorigin(s) in the SQLite database $DB"
		db_print_stats $DB
	fi
	[ $PERFORM_ACTION_WRITE_SQL = yes ] &&
		echo " - PortsDB wrote $UPDATED_PKGORIGIN_COUNT pkgorigin(s) updates into the SQL file $SQL_FILE_ARG"

	return 0
}