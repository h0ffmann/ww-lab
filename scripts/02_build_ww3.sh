#!/usr/bin/env bash
# Build WW3 with CMake.
#
# usage: 02_build_ww3.sh <ww3-dir> <switch-file-or-name> [build-type]
#   switch can be a bare name resolved in <ww3-dir>/model/bin/ (e.g. "Ifremer2")
#   or an absolute/relative path to a switch file (e.g. ../switches/switch_lab_shrd)
set -euo pipefail

WW3DIR="${1:?usage: 02_build_ww3.sh <ww3-dir> <switch> [Release|Debug]}"
SWITCH="${2:?need a switch file}"
BUILD_TYPE="${3:-Release}"
JOBS="${JOBS:-$(nproc)}"

# Resolve to an absolute path if the switch is a real file we ship.
if [ -f "$SWITCH" ]; then
  SWITCH="$(cd "$(dirname "$SWITCH")" && pwd)/$(basename "$SWITCH")"
  echo ">> Using switch file: $SWITCH"
else
  echo ">> Using named switch (resolved in \$WW3/model/bin): $SWITCH"
fi

cd "$WW3DIR"
rm -rf build
mkdir -p build && cd build

cmake .. -DSWITCH="$SWITCH" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
make -j"$JOBS"

echo
echo ">> Executables:"
ls -1 "$WW3DIR/build/bin" 2>/dev/null || ls -1 "$WW3DIR/build" | head -40

cat <<'NOTE'

Tips
----
* Rebuild a single program:   cmake --build . --target ww3_shel
* Debug build:                cmake .. -DCMAKE_BUILD_TYPE=Debug -DSWITCH=<sw>
* Clean:                      rm -rf <ww3-dir>/build
* Changing the switch file requires a FULL rebuild. The switch is baked into the
  preprocessed source; a stale build directory is the single most common cause of
  "I enabled ST4 and nothing changed".
NOTE
