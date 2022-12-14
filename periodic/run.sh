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
## MAIN
##

(
	# start
	echo ""

	# timestamp
	echo "timestamp(begin): $(date "+%Y-%m-%d %H:%M:%S")"

	# pull
	(cd $PORTSDIR && git pull) > git-pull.log
	if [ "$(cat git-pull.log)" = "Already up to date." ]; then
		echo "no updates: nothing to import into PortsDB"
		exit 0
	fi

	# report git log
	echo "---begin git log---"
	cat git-pull.log
	echo "---end git log---"

	# update
	DB_SHA256=$(sha256 -q ports.sqlite)
	PORTSDIR=$PORTSDIR $PORTDSB_UPDATE_CMD
	if [ "$(sha256 -q ports.sqlite)" = $DB_SHA256 ]; then
		echo "no updates: git commits didn't update any pkgorigins"
		exit 0
	fi

	# upload
	echo "uploading ports.sqlite with sha256=$(sha256 -q ports.sqlite) ..."
	$UPLOAD_CMD ports.sqlite

	# timestamp
	echo "timestamp(end): $(date "+%Y-%m-%d %H:%M:%S")"
) >> portsdb.log 2>&1
