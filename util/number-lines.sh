#!/bin/sh

# Copyright (C) 2022 by Yuri Victorovich. All rights reserved.

set -euo pipefail

num=1
while read line; do
	# end?
	[ "$line" = "%%END%%" ] && exit 0

	# print
	echo "$num: $line"

	# inc
	num=$((num+1))
done
