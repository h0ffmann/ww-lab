#!/usr/bin/env bash
# Copy an upstream regtest's input files into ./examples/ so you can edit them
# freely without dirtying your WW3 clone.
#
# usage: stage_upstream_example.sh <ww3-dir> <regtest-name> [dest-dir]
set -euo pipefail
WW3DIR="${1:?}"; TEST="${2:?}"; DEST="${3:-../examples/upstream-$TEST}"
mkdir -p "$DEST"
cp -r "$WW3DIR/regtests/$TEST/input/"* "$DEST/"
cp "$WW3DIR/regtests/$TEST/info" "$DEST/UPSTREAM-INFO.txt" 2>/dev/null || true
echo ">> staged $TEST -> $DEST"
ls -1 "$DEST"
