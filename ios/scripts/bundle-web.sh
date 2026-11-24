#!/bin/sh
# Copies the web tools from the repository's tools/ folder into the app bundle (web/), at every build.
# The files are not duplicated in the repository, so upstream changes to tools/ ship with the next build.
# Everything is copied except what is clearly not part of the web pages (scripts, notes, emulator and
# exploration sources), so new assets upstream (images, fonts, modules, data) come along without changes here.
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
find . \( -name emulator -o -name exploration -o -name __pycache__ -o -name '.?*' \) -prune -o -type f \
  ! -name '*.py' ! -name '*.pyc' ! -name '*.md' ! -name '*.cpp' ! -name '*.c' ! -name '*.h' ! -name '*.sh' \
  ! -name '*.syx' ! -name '*.bin' -print |
while IFS= read -r f; do
  mkdir -p "$DST/$(dirname "$f")"
  cp "$f" "$DST/$f"
done
echo "Bundled $(find "$DST" -type f | wc -l | tr -d ' ') web files from $SRC"
