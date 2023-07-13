#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"
###############################################################
## Abstract:
## Create biomass burning emissions for FV3-CHEM
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base prepchem"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done
###############################################################
export DATA="$RUNDIR/$CDATE/$CDUMP"

[[ ! -d $DATA ]] && mkdir -p $DATA
cd $DATA || exit 10
mkdir -p prep
cd prep

res=`echo $CASE | cut -c2-4`


if [ $EMITYPE -eq 1 ]; then
  module list
  for x in prep_chem_sources_template.inp prep_chem_sources
      do
      # eval $NLN $EMIDIR/$x 
      $NCP ${EMIDIR}${CASE}/$x .
      done
  echo "in FV3_fim_emission_setup:"
  emiss_date="$SYEAR-$SMONTH-$SDAY-$SHOUR" # default value for branch testing      
  echo "emiss_date: $emiss_date"
  echo "yr: $SYEAR mm: $SMONTH dd: $SDAY hh: $SHOUR"
fi

if [ $EMITYPE -eq 1 ]; then
  # put date in input file
      sed "s/fv3_hh/$SHOUR/g;
           s/fv3_dd/$SDAY/g;
           s/fv3_mm/$SMONTH/g;
           s/fv3_yy/$SYEAR/g" prep_chem_sources_template.inp > prep_chem_sources.inp
  . $MODULESHOME/init/sh 2>/dev/null
  module list
  module purge
  module list
  module load intel/14.0.2
  module load szip/2.1
  module load hdf5/1.8.14
  module load netcdf/4.3.0
  module list
  ./prep_chem_sources || fail "ERROR: prep_chem_sources failed."
  status=$?
  if [ $status -ne 0 ]; then
       echo "error prep_chem_sources failed  $status "
       exit $status
  fi
fi
 
for n in $(seq 1 6); do
    tiledir=tile${n}
    #mkdir -p $tiledir
    #cd $tiledir
    EMIINPUT=/scratch1/BMC/gsd-fv3-dev/Haiqin.Li/Develop/emi_${CASE}
#    if [ ${EMIYEAR} -gt 2018 ];  then
    eval $NLN $EMIINPUT/EMI_$EMIYEAR/$SMONTH/emi_data.tile${n}.nc .
#    else
#    eval $NLN $EMIINPUT/EMI/$SMONTH/emi_data.tile${n}.nc .
#    fi

    eval $NLN $EMIINPUT/EMI2/$SMONTH/emi2_data.tile${n}.nc .
    eval $NLN $EMIINPUT/fengsha/$SMONTH/dust_data.tile${n}.nc .
    
    if [ $EMITYPE -eq 1 ]; then
      mkdir -p $tiledir
      cd $tiledir
      eval $NLN ${CASE}-T-${emiss_date}0000-BBURN3-bb.bin ebu_pm_10.dat
      eval $NLN ${CASE}-T-${emiss_date}0000-SO4-bb.bin ebu_sulf.dat
      eval $NLN ${CASE}-T-${emiss_date}0000-plume.bin plumestuff.dat
      eval $NLN ${CASE}-T-${emiss_date}0000-OC-bb.bin ebu_oc.dat
      eval $NLN ${CASE}-T-${emiss_date}0000-BC-bb.bin ebu_bc.dat
      eval $NLN ${CASE}-T-${emiss_date}0000-BBURN2-bb.bin ebu_pm_25.dat
      eval $NLN ${CASE}-T-${emiss_date}0000-SO2-bb.bin ebu_so2.dat
    fi
    if [ $EMITYPE -eq 2 ]; then
      if [ ${res} -eq 384 ];  then
         DIRGB=/scratch1/BMC/gsd-fv3-dev/lzhang/GBBEPx
      else
         DIRGB=/scratch1/BMC/gsd-fv3-dev/lzhang/GBBEPx/${CASE}
      fi
      NCGB=/scratch1/BMC/gsd-fv3-dev/Haiqin.Li/Develop/emi_${CASE}/GBBEPx
      PUBEMI=/scratch2/BMC/public/data/grids/sdsu/emissions
      #PUBEMI=/scratch2/NCEPDEV/stmp1/Li.Pan/tmp
    
      emiss_date1="$SYEAR$SMONTH$SDAY" # default value for branch testing      
      echo "emiss_date: $emiss_date1"
      #mkdir -p $DIRGB/$emiss_date1
      #$NCP $PUBEMI/*${emiss_date1}.*.bin $DIRGB/$emiss_date1/
    
      if [[ -f $NCGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc ]]; then
        echo "NetCDF GBBEPx File $DIRGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc  exists, just link."
      else
    
        if [ ${SYEAR} -eq 2016 ];  then
          BC=GBBEPx.emis_BC.003.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          OC=GBBEPx.emis_OC.003.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          PM25=GBBEPx.emis_PM25.003.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          SO2=GBBEPx.emis_SO2.003.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          FRP=GBBEPx.FRP.003.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
        else
          BC=GBBEPx.bc.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          OC=GBBEPx.oc.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          PM25=GBBEPx.pm25.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          SO2=GBBEPx.so2.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
          FRP=meanFRP.${emiss_date1}.FV3.${CASE}Grid.tile${n}.bin
        fi
      
        mkdir -p $NCGB/${emiss_date1}
        set -ue
        module load intel netcdf szip hdf5
        set -x
        $NLN $EXECgfs/mkncgbbepx .
 ./mkncgbbepx <<EOF
&mkncgbbepx
       title = "GBBEPx emission input (${CASE}, 10, tile${n})"
       tile = ${n}
       date = '$SYEAR-$SMONTH-$SDAY'
       nlon = ${res}
       nlat = ${res}
       outfile     = "$NCGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc"
       pathoro     = "$FIXgfs/fix_fv3/${CASE}/${CASE}_oro_data.tile${n}.nc"
       pathebc     = "$DIRGB/${emiss_date1}/$BC"
       patheoc     = "$DIRGB/${emiss_date1}/$OC"
       pathepm25   = "$DIRGB/${emiss_date1}/$PM25"
       patheso2    = "$DIRGB/${emiss_date1}/$SO2"
       patheplume  = "$DIRGB/${emiss_date1}/$FRP"
/
EOF
        status=$?
        if [ $status -ne 0 ]; then
             echo "error mkncgbbepx failed  $status "
             exit $status
        fi
      fi
      eval $NLN $NCGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc .
    fi
    
    if [ $EMITYPE -eq 1 ]; then 
      rm *-ab.bin
      rm ${CASE}-T-${emiss_date}0000-ALD-bb.bin
      rm ${CASE}-T-${emiss_date}0000-ASH-bb.bin
      rm ${CASE}-T-${emiss_date}0000-CO-bb.bin
      rm ${CASE}-T-${emiss_date}0000-CSL-bb.bin
      rm ${CASE}-T-${emiss_date}0000-DMS-bb.bin
      rm ${CASE}-T-${emiss_date}0000-ETH-bb.bin
      rm ${CASE}-T-${emiss_date}0000-HC3-bb.bin
      rm ${CASE}-T-${emiss_date}0000-HC5-bb.bin
      rm ${CASE}-T-${emiss_date}0000-HC8-bb.bin
      rm ${CASE}-T-${emiss_date}0000-HCHO-bb.bin
      rm ${CASE}-T-${emiss_date}0000-ISO-bb.bin
      rm ${CASE}-T-${emiss_date}0000-KET-bb.bin
      rm ${CASE}-T-${emiss_date}0000-NH3-bb.bin
      rm ${CASE}-T-${emiss_date}0000-NO2-bb.bin
      rm ${CASE}-T-${emiss_date}0000-NO-bb.bin
      rm ${CASE}-T-${emiss_date}0000-OLI-bb.bin
      rm ${CASE}-T-${emiss_date}0000-OLT-bb.bin
      rm ${CASE}-T-${emiss_date}0000-ORA2-bb.bin
      rm ${CASE}-T-${emiss_date}0000-TOL-bb.bin
      rm ${CASE}-T-${emiss_date}0000-XYL-bb.bin
      cd ..
      rm *-g${n}.ctl *-g${n}.vfm *-g${n}.gra
    fi
done
rc=$?
if [ $rc -ne 0 ]; then
     echo "error prepchem $rc "
     exit $rc
fi 


###############################################################

###############################################################
# Exit cleanly

