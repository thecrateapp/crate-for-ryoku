#!/usr/bin/env bash
# Lay out the standalone Obsidian theme repository (thecrateapp/obsidian-crate)
# in DEST: manifest.json and theme.css at the root, as the community directory
# and Obsidian's installer expect, with the README, LICENSE, screenshots and
# the tag-to-release workflow. DEST is created; an existing DEST must be a git
# checkout of that repository (its .git is kept, everything else replaced).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dest=${1:?usage: apps/obsidian/export.sh DEST}
if [ -d "$dest" ] && [ -n "$(ls -A "$dest")" ]; then
  # only ever replace the files of an obsidian-crate checkout
  grep -qs '"name": "Crate"' "$dest/manifest.json" && [ -d "$dest/.git" ] \
    || { echo "export.sh: $dest is not empty and not an obsidian-crate checkout" >&2; exit 1; }
fi
mkdir -p "$dest"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
python3 "$here/../build.py" "$tmp" >/dev/null
find "$dest" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +
cp "$tmp/obsidian/Crate/theme.css" "$tmp/obsidian/Crate/manifest.json" "$dest/"
cp -a "$here/community/." "$dest/"
rm -f -- "$dest/community-css-themes-entry.json"
echo "exported to $dest (version $(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$dest/manifest.json"))"
