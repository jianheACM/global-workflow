#!/usr/bin/env bash

# NOTE:
# The workflow environment is initialized by JGLOBAL_STAGE_IC_S2S.
# The old ${USHgfs}/preamble.sh no longer exists in the new workflow.

# ----------------------------------------------------------------------
# Resolve COM path templates
#
# The old workflow used:
#
#   declare_from_tmpl
#
# The new workflow no longer provides this function.  This helper resolves
# ${ROTDIR}, ${RUN}, ${YMD}, ${HH}, ${MEMDIR}, etc. in the COM_*_TMPL
# variables.
# ----------------------------------------------------------------------
resolve_com_tmpl() {
    local tmpl="${1}"
    local run="${2}"
    local ymd="${3}"
    local hh="${4}"
    local memdir="${5:-}"

    python3 - \
        "${tmpl}" \
        "${ROTDIR}" \
        "${run}" \
        "${ymd}" \
        "${hh}" \
        "${memdir}" \
        "${CDUMP:-}" \
        "${PDY:-}" \
        "${cyc:-}" <<'PY'
import os
import sys
from string import Template

tmpl = sys.argv[1]

mapping = dict(os.environ)

mapping.update({
    "ROTDIR": sys.argv[2],
    "RUN": sys.argv[3],
    "YMD": sys.argv[4],
    "HH": sys.argv[5],
    "MEMDIR": sys.argv[6],
    "CDUMP": sys.argv[7],
    "PDY": sys.argv[8],
    "cyc": sys.argv[9],
})

print(Template(tmpl).safe_substitute(mapping))
PY
}


# ----------------------------------------------------------------------
# Utility for copying files while accumulating errors
# ----------------------------------------------------------------------
err=0

error_message() {
    echo "FATAL ERROR: Unable to copy ${1} to ${2} (Error code ${3})"
}

copy_file() {
    local src="${1}"
    local tgt="${2}"
    local rc=0

    if cp -p "${src}" "${tgt}"; then
        return 0
    else
        rc=$?
        error_message "${src}" "${tgt}" "${rc}"
        err=$((err + rc))
        return 0
    fi
}


# ----------------------------------------------------------------------
# Previous cycle information
# ----------------------------------------------------------------------
GDATE=$(date --utc -d "${PDY} ${cyc} - ${assim_freq} hours" +%Y%m%d%H)

gPDY="${GDATE:0:8}"
gcyc="${GDATE:8:2}"


# ----------------------------------------------------------------------
# Ensemble-member directories
# ----------------------------------------------------------------------
MEMDIR_ARRAY=()

if [[ "${RUN:-}" == "gefs" ]]; then

    # Populate member directories based on NMEM_ENS
    for ((ii = 0; ii <= "${NMEM_ENS:-0}"; ii++)); do
        MEMDIR_ARRAY+=("mem$(printf "%03d" "${ii}")")
    done

else
    MEMDIR_ARRAY+=("")
fi


###############################################################
# Loop over ensemble members
###############################################################
for MEMDIR in "${MEMDIR_ARRAY[@]}"; do

    # ==============================================================
    # Atmosphere initial conditions
    # ==============================================================

    if [[ "${EXP_WARM_START:-.false.}" == ".true." ]]; then

        # ----------------------------------------------------------
        # Warm start: stage FV3 restart files
        # ----------------------------------------------------------

        COM_ATMOS_RESTART_PREV=$(
            resolve_com_tmpl \
                "${COM_ATMOS_RESTART_TMPL}" \
                "${rCDUMP}" \
                "${gPDY}" \
                "${gcyc}" \
                "${MEMDIR}"
        )

        mkdir -p "${COM_ATMOS_RESTART_PREV}"

        for ftype in coupler.res fv_core.res.nc; do

            src="${BASE_CPLIC}/${CPL_ATMIC:-}/${PDY}${cyc}/${MEMDIR}/atmos/${PDY}.${cyc}0000.${ftype}"

            tgt="${COM_ATMOS_RESTART_PREV}/${PDY}.${cyc}0000.${ftype}"

            copy_file "${src}" "${tgt}"

        done


        for ftype in \
            ca_data \
            fv_core.res \
            fv_srf_wnd.res \
            fv_tracer.res \
            phy_data \
            sfc_data
        do

            for ((tt = 1; tt <= 6; tt++)); do

                src="${BASE_CPLIC}/${CPL_ATMIC:-}/${PDY}${cyc}/${MEMDIR}/atmos/${PDY}.${cyc}0000.${ftype}.tile${tt}.nc"

                tgt="${COM_ATMOS_RESTART_PREV}/${PDY}.${cyc}0000.${ftype}.tile${tt}.nc"

                copy_file "${src}" "${tgt}"

            done
        done

    else

        # ----------------------------------------------------------
        # Cold start
        #
        # Keep the customized S2S ICSORG source layout.
        # ----------------------------------------------------------

        COM_ATMOS_INPUT=$(
            resolve_com_tmpl \
                "${COM_ATMOS_INPUT_TMPL}" \
                "${RUN}" \
                "${PDY}" \
                "${cyc}" \
                "${MEMDIR}"
        )

        mkdir -p "${COM_ATMOS_INPUT}"


        # gfs_ctrl.nc
        src="${ICSORG}/${PDY}${cyc}/atmos/${CASE}/INPUT/gfs_ctrl.nc"

        tgt="${COM_ATMOS_INPUT}/gfs_ctrl.nc"

        copy_file "${src}" "${tgt}"


        # gfs_data and sfc_data
        for ftype in gfs_data sfc_data; do

            for ((tt = 1; tt <= 6; tt++)); do

                src="${ICSORG}/${PDY}${cyc}/atmos/${CASE}/INPUT/${ftype}.tile${tt}.nc"

                tgt="${COM_ATMOS_INPUT}/${ftype}.tile${tt}.nc"

                copy_file "${src}" "${tgt}"

            done
        done

    fi


    # ==============================================================
    # Ocean initial conditions
    # ==============================================================

    if [[ "${DO_OCN:-}" == "YES" ]]; then

        COM_OCEAN_RESTART_PREV=$(
            resolve_com_tmpl \
                "${COM_OCEAN_RESTART_TMPL}" \
                "${rCDUMP}" \
                "${gPDY}" \
                "${gcyc}" \
                "${MEMDIR}"
        )

        mkdir -p "${COM_OCEAN_RESTART_PREV}"


        src="${ICSORG}/${PDY}${cyc}/ocn/MOM.res.nc"

        tgt="${COM_OCEAN_RESTART_PREV}/${PDY}.${cyc}0000.MOM.res.nc"

        copy_file "${src}" "${tgt}"


        case "${OCNRES}" in

            "500" | "100")

                # Nothing else required
                ;;


            "025")

                for nn in $(seq 1 3); do

                    src="${ICSORG}/${PDY}${cyc}/ocn/MOM.res_${nn}.nc"

                    tgt="${COM_OCEAN_RESTART_PREV}/${PDY}.${cyc}0000.MOM.res_${nn}.nc"

                    copy_file "${src}" "${tgt}"

                done

                ;;


            *)

                echo "FATAL ERROR: Unsupported ocean resolution ${OCNRES}"

                err=$((err + 1))

                ;;

        esac


        # ----------------------------------------------------------
        # Ocean perturbation files
        # ----------------------------------------------------------

        if (( 0${MEMDIR:3} > 0 )) && \
           [[ "${USE_OCN_PERTURB_FILES:-false}" == "true" ]]; then

            src="${BASE_CPLIC}/${CPL_OCNIC:-}/${PDY}${cyc}/${MEMDIR}/ocean/${PDY}.${cyc}0000.mom6_increment.nc"

            tgt="${COM_OCEAN_RESTART_PREV}/${PDY}.${cyc}0000.mom6_increment.nc"

            copy_file "${src}" "${tgt}"

        fi


        # ----------------------------------------------------------
        # Mediator restart
        # ----------------------------------------------------------

        if [[ "${EXP_WARM_START:-.false.}" == ".true." ]]; then

            COM_MED_RESTART_PREV=$(
                resolve_com_tmpl \
                    "${COM_MED_RESTART_TMPL}" \
                    "${rCDUMP}" \
                    "${gPDY}" \
                    "${gcyc}" \
                    "${MEMDIR}"
            )

            mkdir -p "${COM_MED_RESTART_PREV}"


            src="${BASE_CPLIC}/${CPL_MEDIC:-}/${PDY}${cyc}/${MEMDIR}/med/${PDY}.${cyc}0000.ufs.cpld.cpl.r.nc"

            tgt="${COM_MED_RESTART_PREV}/${PDY}.${cyc}0000.ufs.cpld.cpl.r.nc"


            if [[ -f "${src}" ]]; then

                copy_file "${src}" "${tgt}"

            else

                echo "WARNING: No mediator restarts available with EXP_WARM_START=${EXP_WARM_START}"

            fi

        fi

    fi


    # ==============================================================
    # Ice initial conditions
    # ==============================================================

    if [[ "${DO_ICE:-}" == "YES" ]]; then

        COM_ICE_RESTART_PREV=$(
            resolve_com_tmpl \
                "${COM_ICE_RESTART_TMPL}" \
                "${rCDUMP}" \
                "${gPDY}" \
                "${gcyc}" \
                "${MEMDIR}"
        )

        mkdir -p "${COM_ICE_RESTART_PREV}"


        src="${ICSORG}/${PDY}${cyc}/ice/cice_model_0.25.res_${CDATE}.nc"

        tgt="${COM_ICE_RESTART_PREV}/${PDY}.${cyc}0000.cice_model.res.nc"

        copy_file "${src}" "${tgt}"

    fi


    # ==============================================================
    # Wave initial conditions
    # ==============================================================

    if [[ "${DO_WAVE:-}" == "YES" ]]; then

        COM_WAVE_RESTART=$(
            resolve_com_tmpl \
                "${COM_WAVE_RESTART_TMPL}" \
                "${RUN}" \
                "${PDY}" \
                "${cyc}" \
                "${MEMDIR}"
        )

        mkdir -p "${COM_WAVE_RESTART}"


        for grdID in ${waveGRD}; do

            src="${ICSORG}/${PDY}${cyc}/wav/${PDY}.${cyc}0000.restart.${grdID}"

            tgt="${COM_WAVE_RESTART}/${PDY}.${cyc}0000.restart.${grdID}"

            copy_file "${src}" "${tgt}"

        done

    fi

done


###############################################################
# Final error check
###############################################################
if [[ "${err}" -ne 0 ]]; then

    echo "FATAL ERROR: Unable to stage S2S ICs from ${ICSORG} to ${ROTDIR}; ABORT!"

    exit "${err}"

fi


###############################################################
# Exit cleanly
###############################################################
exit 0
