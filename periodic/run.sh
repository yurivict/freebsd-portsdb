#!/bin/sh

set -euo pipefail

##
## run.sh is a script that updates PortsDB that can be periodically
## run by the cron daemon. It expects that
## 1. FreeBSD ports are cloned into the 'ports' subdirectory
## 2. the user would run the command 'PORTSDB=ports import.sh'
## 3. two variables below are filled in by the user
##
## run.sh performs following actions:
## 1. updates ports.sqlite in the same folder where it is run
## 2. uploads ports.sqlite with the user-supplied command
## 3. maintains the log file portsdb.log
##

##
## user-supplied commands
##

PORTDSB_UPDATE_CMD="" # please add the path to PortDB's update.sh
UPLOAD_CMD="" # please add the command that uploads the DB

##
## global values
##

PORTSDIR=ports

##
## checks
##

if [ -z "$PORTDSB_UPDATE_CMD" -o -z "$UPLOAD_CMD" ]; then
	echo "error: please define PORTDSB_UPDATE_CMD and UPLOAD_CMD"
	exit 1
	
fi

for p in date sha256 sqlite3 git gsed cat sysctl; do
	if [ -z "$(which $p)" ]; then
		echo "error: dependency '$p' is missing"
		exit 1
	fi
done

if ! [ -d $PORTSDIR ]; then
	echo "error: ports tree has to be present (please check it out with 'git clone https://git.FreeBSD.org/ports.git')"
	exit 1
fi

if ! [ -f ports.sqlite ]; then
	echo "error: ports.sqlite has to be present (please build it with 'PORTSDIR=ports update.sh')"
	exit 1
fi

##
## functions
##

db_hash() {
	sha256 -q ports.sqlite
}

timestamp() {
	local location=$1
	echo "timestamp($location, pid=$$): $(date "+%Y-%m-%d %H:%M:%S")"
}

fail() {
	local msg="$1"

	timestamp "error"
	echo "******ERROR: $msg******" >&2

	exit 1
}

##
## MAIN
##

(
	# start
	echo ""

	# variables
	ANY_UPDATES=no

	# timestamp
	timestamp "begin"

	# pull
	(cd $PORTSDIR && git pull) > git-pull.log 2>git-pull.err || fail "git pull failed: $(cat git-pull.err)"
	if [ "$(cat git-pull.log)" = "Already up to date." ]; then
		echo "no updates: nothing to import into PortsDB"
	else
		ANY_UPDATES=yes
	fi

	# report git log
	if [ $ANY_UPDATES = yes ]; then
		echo "---begin git log---"
		cat git-pull.log
		echo "---end git log---"
	fi

	# update
	if [ $ANY_UPDATES = yes ]; then
		# save DB hash
		DB_HASH=$(db_hash)
		# actual update
		(PORTSDIR=$PORTSDIR $PORTDSB_UPDATE_CMD) 2>update.err || fail "update command failed: $(cat update.err)"
		if [ $(db_hash) = $DB_HASH ]; then
			echo "no updates: git commits didn't update any pkgorigins"
			ANY_UPDATES=no
		fi
	fi

	# upload
	if [ $ANY_UPDATES = yes ] || ! [ -f ports.sqlite.sha256 ] || [ "$(cat ports.sqlite.sha256)" != $(db_hash) ]; then
		echo "uploading ports.sqlite with sha256=$(db_hash) ..."
		# actual upload
		($UPLOAD_CMD ports.sqlite) > upload.log 2>upload.err || fail "upload command failed: $(cat upload.err)"
		# save last uploaded DB hash
		echo $(db_hash) > ports.sqlite.sha256
	fi

	# timestamp
	timestamp "end"
) >> portsdb.log 2>&1
