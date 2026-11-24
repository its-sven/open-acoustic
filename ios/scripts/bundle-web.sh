#!/bin/sh
# Copies the web tools from the repository's tools/ folder into the app bundle (web/), at every build.
# The files are not duplicated in the repository, so upstream changes to tools/ ship with the next build.
# Only what the pages load is copied: HTML, JS, CSS and images; no Python, notes or emulator sources.
set -eu

SRC="${SRCROOT}/../tools"
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/web"

if [ ! -f "$SRC/pa-remote.html" ]; then
  echo "error: web tools not found at $SRC" >&2
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST"
cd "$SRC"
find . \( -name emulator -o -name exploration -o -name '.?*' \) -prune -o -type f \
  \( -name '*.html' -o -name '*.js' -o -name '*.css' -o -name '*.png' -o -name '*.svg' -o -name '*.json' \) -print |
while IFS= read -r f; do
  mkdir -p "$DST/$(dirname "$f")"
  cp "$f" "$DST/$f"
done
echo "Bundled $(find "$DST" -type f | wc -l | tr -d ' ') web files from $SRC"
