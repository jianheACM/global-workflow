#!/bin/ksh -x

###############################################################
## Abstract:
## Get GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base getic"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env getic
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

yyyymmdd=$(echo $CDATE |cut -c1-8)
yyyy=$(echo $CDATE | cut -c1-4)
mm=$(echo $CDATE | cut -c5-6)
dd=$(echo $CDATE | cut -c7-8)
hh=$(echo $CDATE | cut -c9-10)

###############################################################

target_dir=$ICSDIR/$CDATE/$CDUMP
mkdir -p $target_dir
cd $target_dir

ftanal[1]="siganl.${CDUMP}.$CDATE"
ftanal[2]="sfcanl.${CDUMP}.$CDATE"


# Initialize return code to 0
rc=1

if [ $ics_from = "opsgfs" ]; then

    # Handle nemsio and pre-nemsio GFS filenames
#    if [ $CDATE -ge "2019101700" ]; then
        nfanal=2
        #fanal[1]="./${CDUMP}.t${cyc}z.pgrb2.0p25.anl"
        fanal[1]="./${CDUMP}.${yyyymmdd}/${hh}/atmos/${CDUMP}.t${cyc}z.atmanl.nc"
        fanal[2]="./${CDUMP}.${yyyymmdd}/${hh}/atmos/${CDUMP}.t${cyc}z.sfcanl.nc"	
	panal[1]="${CDUMP}.t${cyc}z.atmanl.nc"
        panal[2]="${CDUMP}.t${cyc}z.sfcanl.nc"
        flanal="${fanal[1]} ${fanal[2]}"	
#	tarpref="gpfs_dell1_nco_ops_com"	
#    elif [[ $CDATE -gt "2017072000" && $CDATE -lt "2019061200" ]]; then
#        nfanal=3 #4
#        #fanal[1]="./${CDUMP}.t${cyc}z.pgrbanl"
#        fanal[1]="./${CDUMP}.t${cyc}z.atmanl.nemsio"
#        fanal[2]="./${CDUMP}.t${cyc}z.sfcanl.nemsio"
#        fanal[3]="./${CDUMP}.t${cyc}z.nstanl.nemsio"
#        flanal="${fanal[1]} ${fanal[2]} ${fanal[3]}"
#	tarpref="gpfs_hps_nco_ops_com"       	
#    else
#        nfanal=2 #3
#        [[ $CDUMP = "gdas" ]] && str1=1
#        #fanal[1]="./${CDUMP}${str1}.t${cyc}z.pgrbanl"
#        fanal[1]="./${CDUMP}${str1}.t${cyc}z.sanl"
#        fanal[2]="./${CDUMP}${str1}.t${cyc}z.sfcanl"
#        flanal="${fanal[1]} ${fanal[2]}"
#        tarpref="com2"
#    fi

    # First check the COMROOT for files, if present copy over
    if [[ $machine = "WCOSS_C" || $machine = "WCOSS_DELL_P3" ]]; then

        # Need COMROOT
        module load prod_envir >> /dev/null 2>&1
        
#	if [ $machine = "WCOSS_C" ]; then
	# comdir="/gpfs/dell3/ptmp/emc.glopara/ROTDIRS/v16rt2/gfs/para/$CDUMP.$PDY/$hh/atmos"
         comdir="/gpfs/dell1/nco/ops/com/gfs/para/$CDUMP.$PDY/$hh/atmos"
#	else
#	 comdir="/gpfs/dell3/ptmp/emc.glopara/ROTDIRS/v16rt2/gfs/para/$CDUMP.$PDY/$hh/atmos"	 
#	fi
        
        rc=0
        for i in `seq 1 $nfanal`; do
            if [ -f $comdir/${panal[i]} ]; then
                $NCP $comdir/${panal[i]} ${ftanal[i]}
            else
                rb=1 ; ((rc+=rb))
            fi
        done

    fi

    # Get initial conditions from HPSS
    if [ $rc -ne 0 ]; then


        if [ $CDUMP = "gdas" ]; then
	   if [ $CDATE -ge "2019101700" ]; then
            hpssdir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS_D/gfsv16/v16rt2/${yyyymmdd}${hh}"	   
            tarball="$hpssdir/${CDUMP}.tar"
	   else
            hpssdir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS_D/gfsv16/v16retro2e/${yyyymmdd}${hh}"
	    tarball="$hpssdir/${CDUMP}.tar"	   
	   fi

        elif [ $CDUMP = "gfs" ]; then
	   if [ $CDATE -ge "2019101700" ]; then
            hpssdir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS_D/gfsv16/v16rt2/${yyyymmdd}${hh}"	   	   
            tarball="$hpssdir/gfs_netcdfa.tar"	   
	   else	   
            hpssdir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS_D/gfsv16/v16retro2e/${yyyymmdd}${hh}"	    
	    tarball="$hpssdir/gfs_netcdfa.tar"
	   fi
        fi

        # check if the tarball exists
        hsi ls -l $tarball
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "$tarball does not exist and should, ABORT!"
            exit $rc
        fi
        # get the tarball
        htar -xvf $tarball $flanal
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "untarring $tarball failed, ABORT!"
            exit $rc
        fi

        # Move the files to legacy EMC filenames
        for i in `seq 1 $nfanal`; do
            $NMV ${fanal[i]} ${ftanal[i]}
        done

    fi

    # If found, exit out
    if [ $rc -ne 0 ]; then
        echo "Unable to obtain operational GFS initial conditions, ABORT!"
        exit 1
    fi

elif [ $ics_from = "pargfs" ]; then

    # Filenames in parallel
    nfanal=4
    fanal[1]="pgbanl.${CDUMP}.$CDATE"
    fanal[2]="gfnanl.${CDUMP}.$CDATE"
    fanal[3]="sfnanl.${CDUMP}.$CDATE"
    fanal[4]="nsnanl.${CDUMP}.$CDATE"
    flanal="${fanal[1]} ${fanal[2]} ${fanal[3]} ${fanal[4]}"

    # Get initial conditions from HPSS from retrospective parallel
    tarball="$HPSS_PAR_PATH/${CDATE}${CDUMP}.tar"

    # check if the tarball exists
    hsi ls -l $tarball
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "$tarball does not exist and should, ABORT!"
        exit $rc
    fi
    # get the tarball
    htar -xvf $tarball $flanal
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "untarring $tarball failed, ABORT!"
        exit $rc
    fi

    # Move the files to legacy EMC filenames
    for i in $(seq 1 $nfanal); do
        $NMV ${fanal[i]} ${ftanal[i]}
    done

    # If found, exit out
    if [ $rc -ne 0 ]; then
        echo "Unable to obtain parallel GFS initial conditions, ABORT!"
        exit 1
    fi

else

    echo "ics_from = $ics_from is not supported, ABORT!"
    exit 1

fi

#get fv3gfs gdas.txxz.atmanl.nemsio file
echo "YYYYMMDDHH:  ${yyyymmdd}${hh}"

if [ $CDATE -ge "2019101700" ]; then
    hpssdir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS_D/gfsv16/v16rt2/${yyyymmdd}${hh}"	
    gdasfile="$hpssdir/gdas.tar"
#    delldir="/gpfs/dell3/ptmp/emc.glopara/ROTDIRS/v16rt2/gfs/para/gdas.${yyyymmdd}/${hh}/atmos"
    delldir="/gpfs/dell1/nco/ops/com/gfs/para/gdas.${yyyymmdd}/${hh}/atmos"    
else
    hpssdir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS_D/gfsv16/v16retro2e/${yyyymmdd}${hh}"	
    gdasfile="$hpssdir/gdas.tar"
fi

findgdas=0
hsi -q list $gdasfile
status=$?
if [[ $status -eq 0 ]]; then
 findgdas=1
 if [ $CDATE -ge "2019101700" ]; then
  htar -xvf ${gdasfile} ./gdas.${yyyymmdd}/${hh}/atmos/gdas.t${hh}z.atmanl.nc
 else
  htar -xvf ${gdasfile} ./gdas.${yyyymmdd}/${hh}/gdas.t${hh}z.atmanl.nc 
 fi

        rc=$?
        if [ $rc -ne 0 ]; then
            echo "untarring $tarball failed, ABORT!"
            exit $rc
        fi
 if [ $CDATE -ge "2019101700" ]; then
  mv ./gdas.${yyyymmdd}/${hh}/atmos/gdas.t${hh}z.atmanl.nc .
  rm -rf ./gdas.${yyyymmdd}
 else
  mv ./gdas.${yyyymmdd}/${hh}/gdas.t${hh}z.atmanl.nc .
  rm -rf ./gdas.${yyyymmdd}
 fi
 
fi

ls -l $delldir/gdas.t${hh}z.atmanl.nc
status=$?
if [[ $status -eq 0 ]]; then
 findgdas=1
 cp $delldir/gdas.t${hh}z.atmanl.nc .
fi

if [ $findgdas -ne 1 ]; then
    echo "missing gdasfile file"
    exit 1
fi
###############################################################

# Copy pgbanl file to COMROT for verification
#COMROT=$ROTDIR/${CDUMP}.$PDY/$cyc
#[[ ! -d $COMROT ]] && mkdir -p $COMROT
#$NCP ${ftanal[1]} $COMROT/${CDUMP}.t${cyc}z.pgrbanl

###############################################################
# Exit out cleanly
exit 0
