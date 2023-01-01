#!/bin/sh

# Copyright (C) 2022-2023 by Yuri Victorovich. All rights reserved.

STRICT="set -euo pipefail"
$STRICT

ESC=$'\e'

in_terminal=no
[ -t 1 ] && in_terminal=yes

len=0

clr() {
	$STRICT
	if [ $len -gt 0 ]; then
		echo -n "${ESC}[1K" # erase
		echo -n "${ESC}[${len}D" # backwards
	fi
}

tm_start=$(date +"%s")
tm_last=$tm_start
while read line; do
	# end?
	[ "$line" = "%%END%%" ] && break

	# display
	if [ $in_terminal = yes ]; then
		# current time
		tm_now=$(date +"%s")

		if [ $((tm_last+1)) -le $tm_now ]; then
			# clear the previous one if present
			clr

			# add time
			line="$line ($((tm_now - tm_start)) sec)"

			# save length
			len=${#line}

			# display
			echo -n "$line"

			# update time
			tm_last=$tm_now
		fi
	else
		echo $line
	fi
done

# clear last
[ $in_terminal = yes ] && clr
