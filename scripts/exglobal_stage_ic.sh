#!/usr/bin/env bash

source "${USHgfs}/preamble.sh"

# Locally scoped variables and functions
# shellcheck disable=SC2153
GDATE=$(date --utc -d "${PDY} ${cyc} - ${assim_freq} hours" +%Y%m%d%H)
gPDY="${GDATE:0:8}"
gcyc="${GDATE:8:2}"

MEMDIR_ARRAY=()
if [[ "${RUN:-}" = "gefs" ]]; then
  # Populate the member_dirs array based on the value of NMEM_ENS
  for ((ii = 0; ii <= "${NMEM_ENS:-0}"; ii++)); do
    MEMDIR_ARRAY+=("mem$(printf "%03d" "${ii}")")
  done
else
  MEMDIR_ARRAY+=("")
fi

# Initialize return code
err=0

error_message() {
  echo "FATAL ERROR: Unable to copy ${1} to ${2} (Error code ${3})"
}

###############################################################
for MEMDIR in "${MEMDIR_ARRAY[@]}"; do

  # Stage atmosphere initial conditions to ROTDIR
  if [[ ${EXP_WARM_START:-".false."} = ".true." ]]; then
    # Stage the FV3 restarts to ROTDIR (warm start)
    RUN=${rCDUMP} YMD=${gPDY} HH=${gcyc} declare_from_tmpl COM_ATMOS_RESTART_PREV:COM_ATMOS_RESTART_TMPL
    [[ ! -d "${COM_ATMOS_RESTART_PREV}" ]] && mkdir -p "${COM_ATMOS_RESTART_PREV}"
    for ftype in coupler.res fv_core.res.nc; do
      src="${BASE_CPLIC}/${CPL_ATMIC:-}/${PDY}${cyc}/${MEMDIR}/atmos/${PDY}.${cyc}0000.${ftype}"
      tgt="${COM_ATMOS_RESTART_PREV}/${PDY}.${cyc}0000.${ftype}"
      ${NCP} "${src}" "${tgt}"
      rc=$?
      ((rc != 0)) && error_message "${src}" "${tgt}" "${rc}"
      err=$((err + rc))
    done
    for ftype in ca_data fv_core.res fv_srf_wnd.res fv_tracer.res phy_data sfc_data; do
      for ((tt = 1; tt <= ntiles; tt++)); do
        src="${BASE_CPLIC}/${CPL_ATMIC:-}/${PDY}${cyc}/${MEMDIR}/atmos/${PDY}.${cyc}0000.${ftype}.tile${tt}.nc"
        if (( tt > 6 )) ; then
            tgt="${COM_ATMOS_RESTART_PREV}/${PDY}.${cyc}0000.${ftype}.nest0$((tt-5)).tile${tt}.nc"
        else
            tgt="${COM_ATMOS_RESTART_PREV}/${PDY}.${cyc}0000.${ftype}.tile${tt}.nc"
        fi
        ${NCP} "${src}" "${tgt}"
        rc=$?
        ((rc != 0)) && error_message "${src}" "${tgt}" "${rc}"
        err=$((err + rc))
      done
    done
  else
    # Stage the FV3 cold-start initial conditions to ROTDIR
    YMD=${PDY} HH=${cyc} declare_from_tmpl COM_ATMOS_INPUT
    [[ ! -d "${COM_ATMOS_INPUT}" ]] && mkdir -p "${COM_ATMOS_INPUT}"
    #src="$ICSORG/${CDUMP}.${PDY}/${cyc}/atmos/INPUT/gfs_ctrl.nc"
    #JianHe:
    src="$ICSORG/${CDUMP}.${PDY}/${cyc}/model_data/atmos/input/gfs_ctrl.nc"
    #src="${BASE_CPLIC}/${CPL_ATMIC:-}/${PDY}${cyc}/${MEMDIR}/atmos/gfs_ctrl.nc"
    tgt="${COM_ATMOS_INPUT}/gfs_ctrl.nc"
    ${NCP} "${src}" "${tgt}"
    rc=$?
    ((rc != 0)) && error_message "${src}" "${tgt}" "${rc}"
    err=$((err + rc))
    for ftype in gfs_data sfc_data; do
      for ((tt = 1; tt <= ntiles; tt++)); do
        #src="$ICSORG/${CDUMP}.${PDY}/${cyc}/atmos/INPUT/${ftype}.tile${tt}.nc"
	#JianHe:
	src="$ICSORG/${CDUMP}.${PDY}/${cyc}/model_data/atmos/input/${ftype}.tile${tt}.nc"
        #src="${BASE_CPLIC}/${CPL_ATMIC:-}/${PDY}${cyc}/${MEMDIR}/atmos/${ftype}.tile${tt}.nc"
        tgt="${COM_ATMOS_INPUT}/${ftype}.tile${tt}.nc"
        ${NCP} "${src}" "${tgt}"
        rc=$?
        ((rc != 0)) && error_message "${src}" "${tgt}" "${rc}"
        err=$((err + rc))
      done
      if (( ntiles > 6 )); then
        ${NLN} "${COM_ATMOS_INPUT}/${ftype}.tile7.nc" "${COM_ATMOS_INPUT}/${ftype}.nest02.tile7.nc"
      fi
    done

 fi


done # for MEMDIR in "${MEMDIR_ARRAY[@]}"; do

###############################################################
# Check for errors and exit if any of the above failed
if [[ "${err}" -ne 0 ]]; then
  echo "FATAL ERROR: Unable to copy ICs from ${BASE_CPLIC} to ${ROTDIR}; ABORT!"
  exit "${err}"
fi

##############################################################
# Exit cleanly
exit "${err}"
