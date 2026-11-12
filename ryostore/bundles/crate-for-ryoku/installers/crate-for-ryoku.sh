#!/bin/bash
# SPDX-License-Identifier: MIT
# Crate for Ryoku: lay the package's pieces into this user's home and apply the
# rice. Source: https://github.com/thecrateapp/crate-for-ryoku
# The crate-for-ryoku package (a package item of this bundle, installed first)
# provides the command; this script only runs it, as the user, without root.
set -euo pipefail
if ryoku-cmd-present crate-for-ryoku-installed; then
  echo "crate-for-ryoku: already set up ($(crate-for-ryoku-installed))"
  exit 0
fi
if ! ryoku-cmd-present crate-for-ryoku; then
  echo "crate-for-ryoku: install the crate-for-ryoku package first" >&2
  exit 1
fi
crate-for-ryoku install
