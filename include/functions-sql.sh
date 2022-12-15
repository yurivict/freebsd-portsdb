#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.


##
## set strict mode
##

set -euo pipefail

##
## functions (shared between low and high level)
##

run_SQL() {
	local SQL="$1"

	# save SQL statements into a file
	echo "$SQL;" >> "$SQL_FILE"
}
