#!/bin/sh

# Copyright (C) 2022-2023 by Yuri Victorovich. All rights reserved.

set -euo pipefail


PARAM_PORTSTREE_NEEDS_PATCHING=yes
PARAM_PORTSDB_UPDATE_LIMIT=1000000 # number of updated pkgorigins that triggers import instead of update (TODO)
