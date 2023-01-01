#!/bin/sh

# Copyright (C) 2022-2023 by Yuri Victorovich. All rights reserved.


##
## functions (shared between low and high level)
##

## set strict mode
STRICT="set -euo pipefail"
$STRICT


run_SQL() {
	$STRICT
	local SQL="$1"

	# save SQL statements into a file
	echo "$SQL;" >> "$SQL_FILE"
}
