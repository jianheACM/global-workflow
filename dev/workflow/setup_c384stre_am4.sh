#!/usr/bin/env bash
set -euo pipefail

# Override these settings here or through the environment.
PSLOT="${PSLOT:-C384streL128_CYCL_AM4_native}"
COMROOT="${COMROOT:-/scratch3/BMC/rcm2/jhe/ufschem/COMROOT}"
EXPDIR="${EXPDIR:-/scratch3/BMC/rcm2/jhe/ufschem/EXPDIR}"
IDATE="${IDATE:-2023051500}"
# Start GFS after at least one six-hour GDAS forecast.
SDATE_GFS="${SDATE_GFS:-$(date -u -d "${IDATE:0:8} ${IDATE:8:2}:00 UTC + 6 hours" +%Y%m%d%H)}"
EDATE="${EDATE:-$SDATE_GFS}"
INTERVAL="${INTERVAL:-24}"

# Set ICSDIR here, pass an IC root, or edit the generated config.stage_ic.
ICSDIR="${ICSDIR:-}"
if [[ $# -gt 0 && $1 != -* ]]; then
    ICSDIR="$1"
    shift
fi
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --submit ) ]]; then
    printf 'Usage: %s [IC_ROOT] [--submit]\n' "${0##*/}" >&2
    exit 2
fi

workflow_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
YAML="${YAML:-$workflow_dir/../parm/config/gfs/yaml/am4_c384stre_native.yaml}"
[[ "$YAML" = /* ]] || YAML="$PWD/$YAML"
if [[ ! -f "$YAML" ]]; then
    printf 'Missing workflow preset: %s\n' "$YAML" >&2
    exit 1
fi

if [[ -n "$ICSDIR" ]]; then
    ICSDIR="$(cd -- "$ICSDIR" && pwd)"
    input_dir="$ICSDIR/gdas.${IDATE:0:8}/${IDATE:8:2}/model/atmos/input"
    ic_files=(gfs_ctrl.nc)
    for tile in {1..6}; do
        ic_files+=("gfs_data.tile$tile.nc" "sfc_data.tile$tile.nc")
    done
    for file in "${ic_files[@]}"; do
        if [[ ! -f "$input_dir/$file" ]]; then
            printf 'Missing IC file: %s\n' "$input_dir/$file" >&2
            exit 1
        fi
    done
else
    if [[ ${1:-} == --submit ]]; then
        printf 'Set ICSDIR or pass an IC root before submitting.\n' >&2
        exit 2
    fi
    ICSDIR="/path/to/stretched_ics"
    printf 'Set ICSDIR in %s/config.stage_ic before running Rocoto.\n' "$EXPDIR/$PSLOT"
fi

"$workflow_dir/setup_expt.py" gfs cycled \
    --app ATM --run gdas --start cold --nens 0 \
    --pslot "$PSLOT" --resdetatmos 384 --interval "$INTERVAL" \
    --idate "$IDATE" --edate "$EDATE" --sdate_gfs "$SDATE_GFS" --icsdir "$ICSDIR" \
    --comroot "$COMROOT" --expdir "$EXPDIR" --yaml "$YAML"

experiment_dir="$EXPDIR/$PSLOT"
env -u EXPDIR -u COMROOT -u PSLOT -u ICSDIR "$workflow_dir/setup_workflow.py" "$experiment_dir" rocoto

xml="$experiment_dir/$PSLOT.xml"
printf 'Workflow XML: %s\n' "$xml"
if [[ ${1:-} == --submit ]]; then
    rocotorun -w "$xml" -d "$experiment_dir/$PSLOT.db"
fi
