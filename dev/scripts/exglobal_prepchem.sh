#!/usr/bin/env bash
# CATChem PREPCHEM emission processing for the new global-workflow.
# Called directly by jobs/JGLOBAL_PREPCHEM.
# Job environment and config sourcing are done upstream.
set -euo pipefail

# Carry over old date conventions, unless configs explicitly provide them.
SYEAR="${SYEAR:-${PDY:0:4}}"
SMONTH="${SMONTH:-${PDY:4:2}}"
SDAY="${SDAY:-${PDY:6:2}}"
SHOUR="${SHOUR:-${cyc}}"
EMIYEAR="${EMIYEAR:-${SYEAR}}"
GBDAY="${GBDAY:-1}"

# Stage emissions where forecast_postdet.sh expects them.
PREPCHEM_WORKDIR="${PREPCHEM_WORKDIR:-${DATAROOT}/${RUN}fcst.${PDY}${cyc}/prep}"
EMIINPUT="${EMIIN}/emi_${CASE}"
GBBEPX_NC_ROOT="${GBBEPX_NC_ROOT:-${EMIINPUT}/GBBEPx}"

# Review these inherited HPC-specific input directories before running.
PREPCHEM_OROG_ROOT="${PREPCHEM_OROG_ROOT:-${FIXgfs_2022:-/scratch3/BMC/gsd-fv3-dev/lzhang/fix_orog_20220805}}"
GBBEPX_V4_ROOT="${GBBEPX_V4_ROOT:-/scratch4/NCEPDEV/naqfc/Kate.Zhang/GBBPEx_v004}"
GBBEPX_V5_ROOT="${GBBEPX_V5_ROOT:-/scratch3/BMC/gsd-fv3-dev/lzhang/GBBEPx}"

if [[ ! "${GBDAY}" =~ ^[0-9]+$ ]] || (( GBDAY < 1 )); then
    echo "ERROR: GBDAY must be a positive integer; got '${GBDAY}'" >&2
    exit 2
fi

res="${CASE#?}"
if [[ ! "${res}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Unsupported CASE '${CASE}' (expected C96, C384, etc.)" >&2
    exit 2
fi

mkdir -p "${PREPCHEM_WORKDIR}"
cd "${PREPCHEM_WORKDIR}"

link_required() {
    local src="$1" dest="$2"
    if [[ ! -e "${src}" ]]; then
        echo "ERROR: Required input missing: ${src}" >&2
        return 1
    fi
    ln -sfn "${src}" "${dest}"
}

# Old workflow places these monthly emissions inputs in the PREPCHEM directory.
for tile in {1..6}; do
    link_required "${EMIINPUT}/EMI_${EMIYEAR}/${SMONTH}/emi_data.tile${tile}.nc" \
                  "emi_data.tile${tile}.nc"
    link_required "${EMIINPUT}/EMI2/${SMONTH}/emi2_data.tile${tile}.nc" \
                  "emi2_data.tile${tile}.nc"
    link_required "${EMIINPUT}/fengsha_2023/12month/dust_data_g12m.tile${tile}.nc" \
                  "dust_data_g12m.tile${tile}.nc"
done

case "${EMITYPE}" in
    1)
        : "${EMIDIR:?EMIDIR required for EMITYPE=1}"
        # Old PREP_CHEM_SOURCES path (binary must be compatible with current modules).
        cp -p "${EMIDIR%/}/${CASE}/prep_chem_sources_template.inp" .
        cp -p "${EMIDIR%/}/${CASE}/prep_chem_sources" .
        chmod +x ./prep_chem_sources
        emiss_date="${SYEAR}-${SMONTH}-${SDAY}-${SHOUR}"
        sed -e "s/fv3_hh/${SHOUR}/g" \
            -e "s/fv3_dd/${SDAY}/g" \
            -e "s/fv3_mm/${SMONTH}/g" \
            -e "s/fv3_yy/${SYEAR}/g" \
            prep_chem_sources_template.inp > prep_chem_sources.inp
        ./prep_chem_sources

        for tile in {1..6}; do
            mkdir -p "tile${tile}"
            (
                cd "tile${tile}"
                prefix="${CASE}-T-${emiss_date}0000"
                link_required "${prefix}-BBURN3-bb.bin" ebu_pm_10.dat
                link_required "${prefix}-SO4-bb.bin" ebu_sulf.dat
                link_required "${prefix}-plume.bin" plumestuff.dat
                link_required "${prefix}-OC-bb.bin" ebu_oc.dat
                link_required "${prefix}-BC-bb.bin" ebu_bc.dat
                link_required "${prefix}-BBURN2-bb.bin" ebu_pm_25.dat
                link_required "${prefix}-SO2-bb.bin" ebu_so2.dat
                # The original script removes secondary intermediate files here.
                rm -f -- *-ab.bin \
                    "${prefix}-ALD-bb.bin" "${prefix}-ASH-bb.bin" \
                    "${prefix}-CO-bb.bin" "${prefix}-CSL-bb.bin" \
                    "${prefix}-DMS-bb.bin" "${prefix}-ETH-bb.bin" \
                    "${prefix}-HC3-bb.bin" "${prefix}-HC5-bb.bin" \
                    "${prefix}-HC8-bb.bin" "${prefix}-HCHO-bb.bin" \
                    "${prefix}-ISO-bb.bin" "${prefix}-KET-bb.bin" \
                    "${prefix}-NH3-bb.bin" "${prefix}-NO2-bb.bin" \
                    "${prefix}-NO-bb.bin" "${prefix}-OLI-bb.bin" \
                    "${prefix}-OLT-bb.bin" "${prefix}-ORA2-bb.bin" \
                    "${prefix}-TOL-bb.bin" "${prefix}-XYL-bb.bin"
            )
            rm -f -- *-g"${tile}".ctl *-g"${tile}".vfm *-g"${tile}".gra
        done
        ;;
    2)
        # Existing GBBEPx NetCDF products are reused. Otherwise convert binary
        # emissions files for each requested day and FV3 tile.
        if [[ -n "${PREPCHEM_NC_EXE:-}" ]]; then
            nc_exe="${PREPCHEM_NC_EXE}"
        else
            execdir="${EXECglobal:-${EXECgfs:-${HOMEglobal:?HOMEglobal required if EXECglobal and EXECgfs are unset}/exec}}"
            if [[ -x "${execdir}/mkncgbbepx.exe" ]]; then
                nc_exe="${execdir}/mkncgbbepx.exe"
            else
                nc_exe="${execdir}/mkncgbbepx"
            fi
        fi
        if [[ ! -x "${nc_exe}" ]]; then
            echo "ERROR: mkncgbbepx executable not found or not executable: ${nc_exe}" >&2
            exit 1
        fi

        for tile in {1..6}; do
            for (( offset=0; offset<GBDAY; offset++ )); do
                emiss_day="$(date -d "${PDY} + ${offset} day" +%Y%m%d)"
                iso_day="$(date -d "${PDY} + ${offset} day" +%Y-%m-%d)"
                output="${GBBEPX_NC_ROOT}/${emiss_day}/FIRE_GBBEPx_data.tile${tile}.nc"

                if [[ ! -s "${output}" ]]; then
                    if (( 10#${emiss_day} <= 20240501 )); then
                        version="v4r0"
                        input_dir="${GBBEPX_V4_ROOT}/${emiss_day:0:4}/${emiss_day}"
                    else
                        version="v5r0"
                        input_dir="${GBBEPX_V5_ROOT}/${emiss_day}"
                    fi
                    prefix="${CASE}GT${tile}_${version}_${emiss_day}.bin"
                    bc="${input_dir}/GBBEPxemis-BC-${prefix}"
                    oc="${input_dir}/GBBEPxemis-OC-${prefix}"
                    pm25="${input_dir}/GBBEPxemis-PM25-${prefix}"
                    so2="${input_dir}/GBBEPxemis-SO2-${prefix}"
                    frp="${input_dir}/GBBEPxFRP-MeanFRP-${prefix}"
                    oro="${PREPCHEM_OROG_ROOT}/${CASE}/${CASE}_oro_data.tile${tile}.nc"
                    for required in "${bc}" "${oc}" "${pm25}" "${so2}" "${frp}" "${oro}"; do
                        [[ -r "${required}" ]] || {
                            echo "ERROR: GBBEPx input missing: ${required}" >&2
                            exit 1
                        }
                    done
                    mkdir -p "$(dirname "${output}")"
                    "${nc_exe}" <<NAMELIST
&mkncgbbepx
  title       = "GBBEPx emission input (${CASE}, 10, tile${tile})"
  tile        = ${tile}
  date        = '${iso_day}'
  nlon        = ${res}
  nlat        = ${res}
  outfile     = "${output}"
  pathoro     = "${oro}"
  pathebc     = "${bc}"
  patheoc     = "${oc}"
  pathepm25   = "${pm25}"
  patheso2    = "${so2}"
  patheplume  = "${frp}"
/
NAMELIST
                    [[ -s "${output}" ]] || {
                        echo "ERROR: converter did not create ${output}" >&2
                        exit 1
                    }
                fi

                if (( GBDAY == 1 )); then
                    target="FIRE_GBBEPx_data.tile${tile}.nc"
                else
                    target="d$((offset+1))_FIRE_GBBEPx_data.tile${tile}.nc"
                fi
                if (( GBDAY == 1 )); then
                    link_required "${output}" "${target}"
                else
                    cp -pf "${output}" "${target}"
                fi
            done
        done
        ;;
    *)
        echo "ERROR: Unsupported EMITYPE=${EMITYPE}; expected 1 or 2" >&2
        exit 2
        ;;
esac

exit 0

