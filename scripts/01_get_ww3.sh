#!/usr/bin/env bash
# Clone WW3 and pull the binary data bundle needed by the regression tests.
#
# usage: 01_get_ww3.sh [dest]   (default: $HOME/src/WW3)
set -euo pipefail

DEST="${1:-$HOME/src/WW3}"
BRANCH="${WW3_BRANCH:-develop}"

if [ -d "$DEST/.git" ]; then
  echo ">> $DEST already a git repo; fetching."
  git -C "$DEST" fetch --all --tags
else
  echo ">> Cloning NOAA-EMC/WW3 ($BRANCH) into $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --branch "$BRANCH" https://github.com/NOAA-EMC/WW3.git "$DEST"
fi

cd "$DEST"

# The repo is only half the package. The other half is a binary data bundle
# (bathymetry, forcing, reference output for the regression tests) that lives
# on NOAA's FTP and is NOT in git.
echo
echo ">> Fetching the regression-test data bundle from NOAA FTP."
echo "   This is a few hundred MB and can be slow. It is required for regtests."
if [ -x ./model/bin/ww3_from_ftp.sh ]; then
  ./model/bin/ww3_from_ftp.sh
else
  echo "!! model/bin/ww3_from_ftp.sh not found -- upstream layout may have changed."
  echo "   Check the Quick Start guide in the repo wiki."
fi

echo
echo ">> Done. Suggested:"
echo "     export WW3=$DEST"
echo "     echo 'export WW3=$DEST' >> ~/.bashrc"
