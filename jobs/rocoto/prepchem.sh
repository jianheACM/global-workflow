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
source $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base fcst  prepchem"
for config in $configs; do
    source $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done
###############################################################
# Source machine runtime environment
source $BASE_ENV/${machine}.env prepchem
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
export DATA="$RUNDIR/${RUN}fcst.${PDY:-}${cyc}"
export FIXgfs_2022="/scratch1/BMC/gsd-fv3-dev/lzhang/fix_orog_20220805"

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
    #eval $NLN $EMIINPUT/fengsha_2023/$SMONTH/dust_data.tile${n}.nc .
    eval $NLN $EMIINPUT/fengsha_2023/12month/dust_data_g12m.tile${n}.nc .

    if [[ "${DO_AM4CHEM:-NO}" == "YES" ]]; then
      echo "Link anthro emissions for AM4"
      rm -f *emi_data.tile${n}nc
      #Need to prepare emissions before model run!!!
      EMIINPUT_am4=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/Emissions/emi_${CASE}
      eval $NLN $EMIINPUT_am4/EMI_$SYEAR/$SMONTH/emi_data.tile${n}.nc .
    fi 

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
      NCGB=/scratch1/BMC/gsd-fv3-dev/Haiqin.Li/Develop/emi_${CASE}/GBBEPx
      PUBEMI=/scratch2/BMC/public/data/grids/sdsu/emissions
      #PUBEMI=/scratch2/NCEPDEV/stmp1/Li.Pan/tmp
    
      emiss_date1="$SYEAR$SMONTH$SDAY" # default value for branch testing      
      echo "emiss_date: $emiss_date1"
      #mkdir -p $DIRGB/$emiss_date1
      #$NCP $PUBEMI/*${emiss_date1}.*.bin $DIRGB/$emiss_date1/
    

      if [[ -f $NCGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc ]]; then
        echo "NetCDF GBBEPx File $NCGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc  exists, just link."
      else
         if [ ${emiss_date1} -le 20240501 ]; then 
          DIRGB=/scratch2/NCEPDEV/naqfc/Kate.Zhang/GBBPEx_v004/$SYEAR
           BC=GBBEPxemis-BC-${CASE}GT${n}_v4r0_${emiss_date1}.bin
           OC=GBBEPxemis-OC-${CASE}GT${n}_v4r0_${emiss_date1}.bin
           PM25=GBBEPxemis-PM25-${CASE}GT${n}_v4r0_${emiss_date1}.bin
           SO2=GBBEPxemis-SO2-${CASE}GT${n}_v4r0_${emiss_date1}.bin
           FRP=GBBEPxFRP-MeanFRP-${CASE}GT${n}_v4r0_${emiss_date1}.bin
         else
          DIRGB=/scratch1/BMC/gsd-fv3-dev/lzhang/GBBEPx
           BC=GBBEPxemis-BC-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           OC=GBBEPxemis-OC-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           SO2=GBBEPxemis-SO2-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           FRP=GBBEPxFRP-MeanFRP-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           PM25=GBBEPxemis-PM25-${CASE}GT${n}_v5r0_${emiss_date1}.bin
         fi
        mkdir -p $NCGB/${emiss_date1}
        set -ue
        module load intel/19.0.5.281 netcdf szip hdf5
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
       pathoro     = "$FIXgfs_2022/${CASE}/${CASE}_oro_data.tile${n}.nc"
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

      rm -rf  *FIRE_GBBEPx_data.tile${n}.nc 

      if [ $GBDAY -eq 1 ]; then
        eval $NLN $NCGB/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc .

	if [[ "${DO_AM4CHEM:-NO}" == "YES" ]]; then
	  echo "Link fire emissions for AM4"
	  #Currently only works for GBDAY=1
	  rm -f  *FIRE_GBBEPx_data.tile${n}.nc
	  am4fire_dir=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/Emissions/emi_C96/FIRE_$SYEAR/
          eval $NLN $am4fire_dir/${emiss_date1}/FIRE_GBBEPx_data.tile${n}.nc .
        fi

      else
        j_day=$(date -d "$emiss_date1" "+%j")           
        echo "Julian day: $j_day"
        end_day=$((j_day+GBDAY-1))
        echo "end_day: $end_day"
       for (( i=${j_day}; i<=${end_day}; i++ )) 
       do
         jd=$((i-j_day+1))
        echo "jd: $jd"
           jj=${jd}
         day_of_year=$i 
         date=$(date -d "$SYEAR-01-01 +$(( $day_of_year - 1 )) days" +"%Y-%m-%d")
         echo "Date: $date"
         nmonth=$(echo $date | awk -F'-' '{print $2}')
         nday=$(echo $date | awk -F'-' '{print $3}')

       if [[ -f $NCGB/${SYEAR}${nmonth}${nday}/FIRE_GBBEPx_data.tile${n}.nc ]]; then
        echo "NetCDF GBBEPx File $NCGB/${SYEAR}${nmonth}${nday}/FIRE_GBBEPx_data.tile${n}.nc  exists, just link."
      else
         if [ ${emiss_date1} -le 20240501 ]; then
         DIRGB=/scratch2/NCEPDEV/naqfc/Kate.Zhang/GBBPEx_v004/$SYEAR
          BC=GBBEPxemis-BC-${CASE}GT${n}_v4r0_${SYEAR}${nmonth}${nday}.bin
          OC=GBBEPxemis-OC-${CASE}GT${n}_v4r0_${SYEAR}${nmonth}${nday}.bin
          PM25=GBBEPxemis-PM25-${CASE}GT${n}_v4r0_${SYEAR}${nmonth}${nday}.bin
          SO2=GBBEPxemis-SO2-${CASE}GT${n}_v4r0_${SYEAR}${nmonth}${nday}.bin
          FRP=GBBEPxFRP-MeanFRP-${CASE}GT${n}_v4r0_${SYEAR}${nmonth}${nday}.bin
         else
	 DIRGB=/scratch1/BMC/gsd-fv3-dev/lzhang/GBBEPx 
           BC=GBBEPxemis-BC-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           OC=GBBEPxemis-OC-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           SO2=GBBEPxemis-SO2-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           FRP=GBBEPxFRP-MeanFRP-${CASE}GT${n}_v5r0_${emiss_date1}.bin
           PM25=GBBEPxemis-PM25-${CASE}GT${n}_v5r0_${emiss_date1}.bin
	 fi

        mkdir -p $NCGB/${SYEAR}${nmonth}${nday}
        set -ue
	module load gnu intel/2023.2.0 netcdf/4.7.0 szip hdf5
        set -x
        $NLN $EXECgfs/mkncgbbepx .
 ./mkncgbbepx <<EOF
&mkncgbbepx
       title = "GBBEPx emission input (${CASE}, 10, tile${n})"
       tile = ${n}
       date = '$SYEAR-$nmonth-$nday'
       nlon = ${res}
       nlat = ${res}
       outfile     = "$NCGB/${SYEAR}${nmonth}${nday}/FIRE_GBBEPx_data.tile${n}.nc"
       pathoro     = "$FIXgfs_2022/${CASE}/${CASE}_oro_data.tile${n}.nc"
       pathebc     = "$DIRGB/${SYEAR}${nmonth}${nday}/$BC"
       patheoc     = "$DIRGB/${SYEAR}${nmonth}${nday}/$OC"
       pathepm25   = "$DIRGB/${SYEAR}${nmonth}${nday}/$PM25"
       patheso2    = "$DIRGB/${SYEAR}${nmonth}${nday}/$SO2"
       patheplume  = "$DIRGB/${SYEAR}${nmonth}${nday}/$FRP"
/
EOF
        status=$?
        if [ $status -ne 0 ]; then
             echo "error mkncgbbepx failed  $status "
             exit $status
        fi
      fi
         eval $NCP $NCGB/${SYEAR}${nmonth}${nday}/FIRE_GBBEPx_data.tile${n}.nc d${jj}_FIRE_GBBEPx_data.tile${n}.nc 
       done
      fi
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

    if [[ "${DO_AM4CHEM:-NO}" == "YES" ]]; then
      echo "Link inputdata required for AM4"
      if [ ${SYEAR} -eq 2016 ];  then
        ICINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/ICs/v20160701/final
      elif [ ${SYEAR} -eq 2017 ];  then
        if [ ${SMONTH} -eq 1 ];  then
          ICINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/ICs/v20170101/final
        else
          ICINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/ICs/v20170901/final
        fi
      else
        ICINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/ICs/v20180401/final
      fi

      eval $NLN $ICINPUT/chemic_data.tile${n}.nc .

      #
      AGEINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/Other
      eval $NLN $AGEINPUT/dfdage3_data.tile${n}.nc .

      # ddep for AM4
      DDEPINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/Depvel
      eval $NLN $DDEPINPUT/$SMONTH/depvel_data.tile${n}.nc .

      JINPUT=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/inputdata/AM4_input/Jval
      eval $NLN $JINPUT/* .
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


exit 0
