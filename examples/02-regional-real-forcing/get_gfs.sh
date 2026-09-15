#!/usr/bin/env bash
# Download GFS 0.25 deg 10 m winds for example 02 from NOMADS and convert them
# to one netCDF file (gfs_winds.nc) that ww3_prnc can read.
#
# usage: get_gfs.sh YYYYMMDD HH [out.nc]        e.g. get_gfs.sh 20260910 00
#
# What it does
#   1. asks NOMADS' filter_gfs_0p25.pl for UGRD/VGRD at 10 m above ground,
#      subset to the example box (52W-44W, 32S-24S), for forecast hours
#      0..192 every 3 h of the cycle YYYYMMDD/HH -- 65 small GRIB2 files;
#   2. merges them along time with `cdo mergetime`;
#   3. converts to netCDF with ecCodes' grib_to_netcdf, which names the
#      variables u10/v10 and the coordinates longitude/latitude/time;
#   4. relabels longitudes to -180..180 if the file came out on 0..360, so the
#      forcing grid overlaps the model grid (ww3_prnc gives zeros, not an
#      error, when the conventions disagree).
#
# NOMADS keeps roughly the last ten days of GFS. Older cycles are on the NOAA
# open-data archive (https://noaa-gfs-bdp-pds.s3.amazonaws.com/) as whole
# files with no server-side subsetting; this script does not go there.
#
# Idempotent: files already downloaded are kept, and the merge/convert steps
# are cheap enough to redo. Needs curl, cdo, grib_to_netcdf, ncap2, ncdump --
# all in `just ww3`.
#
# SPDX-License-Identifier: MIT
set -euo pipefail

DATE="${1:?usage: get_gfs.sh YYYYMMDD HH [out.nc]}"
CYC="${2:?usage: get_gfs.sh YYYYMMDD HH [out.nc]}"
OUT="${3:-gfs_winds.nc}"

[[ "$DATE" =~ ^[0-9]{8}$ ]] || { echo "!! date must be YYYYMMDD, got '$DATE'"; exit 2; }
[[ "$CYC" =~ ^(00|06|12|18)$ ]] || { echo "!! cycle must be 00, 06, 12 or 18, got '$CYC'"; exit 2; }
for tool in curl cdo grib_to_netcdf ncap2 ncdump; do
  command -v "$tool" >/dev/null || { echo "!! $tool not found -- run inside 'just ww3'"; exit 1; }
done

BASE="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl"
BOX="leftlon=-52&rightlon=-44&toplat=-24&bottomlat=-32"
VARS="var_UGRD=on&var_VGRD=on&lev_10_m_above_ground=on"
FIRST=0 LAST=192 STEP=3

WORK="gfs.${DATE}${CYC}"
mkdir -p "$WORK"

echo ">> GFS cycle ${DATE}/${CYC}z, f${FIRST}..f${LAST} every ${STEP} h, box ${BOX//&/ }"
n=0
for ((h = FIRST; h <= LAST; h += STEP)); do
  fff=$(printf '%03d' "$h")
  name="gfs.t${CYC}z.pgrb2.0p25.f${fff}"
  f="$WORK/$name"
  if [ -s "$f" ]; then
    n=$((n + 1))
    continue
  fi
  url="${BASE}?dir=%2Fgfs.${DATE}%2F${CYC}%2Fatmos&file=${name}&${VARS}&subregion=&${BOX}"
  printf '   %s ' "$name"
  # NOMADS answers 404 for cycles it no longer has and 302 to an error page
  # for bad requests; -f turns both into a non-zero exit instead of a
  # GRIB file full of HTML.
  if curl -fsSL --retry 3 --retry-delay 5 -o "$f.part" "$url"; then
    mv "$f.part" "$f"
    n=$((n + 1))
    echo "ok"
  else
    rm -f "$f.part"
    echo "FAILED"
    echo "!! could not fetch $name -- is ${DATE}/${CYC}z still on NOMADS? (about ten days)"
    exit 1
  fi
done
echo ">> $n GRIB2 files in $WORK/"

echo ">> merging along time (cdo mergetime)"
cdo -s -O mergetime "$WORK"/gfs.t"${CYC}"z.pgrb2.0p25.f??? "$WORK/merged.grb2"

echo ">> converting to netCDF (grib_to_netcdf)"
grib_to_netcdf -o "$OUT" "$WORK/merged.grb2" >/dev/null

# grib_to_netcdf keeps the GRIB's 0..360 longitudes; the model grid is on
# -52..-44. Relabel in place when needed (no-op otherwise).
if ncdump -v longitude "$OUT" | awk '/^ longitude =/,/;/' | grep -qE '[0-9]{3}\.'; then
  echo ">> relabelling longitudes 0..360 -> -180..180"
  ncap2 -O -s 'where(longitude > 180.0) longitude = longitude - 360.0;' "$OUT" "$OUT"
fi

echo ">> wrote $OUT"
ncdump -h "$OUT" | sed -n '1,40p'
cat <<NOTE

Check, before running ww3_prnc:
  * the variables are named u10 and v10 and the coordinates longitude, latitude, time
    (ww3_prnc_wind.nml assumes exactly those names; edit FILE%VAR / FILE%LONGITUDE if not);
  * longitude runs -52..-44 (not 308..316) and latitude covers -32..-24;
  * the time axis has $n steps 3 h apart, starting at ${DATE} ${CYC}:00.
The namelists in this directory are dated 2024-07-01 00Z + 8 days. Retime them to
this cycle before running (four files, one sed):
  sed -i 's/20240701 000000/${DATE} ${CYC}0000/; s/20240708 000000/$(date -u -d "${DATE} ${CYC}:00 + 8 days" +%Y%m%d) ${CYC}0000/' \\
      ww3_shel.nml ww3_prnc_wind.nml ww3_ounf.nml ww3_ounp.nml
NOTE
