#!/bin/ksh  -x

## this script makes links to FV3GFS (GFSv15.1) nemsio files under /public and copies over GFS analysis file for verification
##   /scratch4/BMC/rtfim/rtfuns/FV3GFS/FV3ICS/YYYYMMDDHH/gfs
##     gfs.tHHz.sfcanl.nemsio -> /public/data/grids/gfs/nemsio/YYDDDHH00.gfs.tHHz.sfcanl.nemsio
##     gfs.tHHz.atmanl.nemsio -> /public/data/grids/gfs/nemsio/YYDDDHH00.gfs.tHHz.atmanl.nemsio
##

echo
echo "CDATE = $CDATE"
echo "CDUMP = $CDUMP"
echo "COMPONENT = $COMPONENT"
echo "ICSDIR = $ICSDIR"
echo "PUBDIR = $PUBDIR"
echo "GFSDIR = $GFSDIR"
echo "RETRODIR = $RETRODIR"
echo "ROTDIR = $ROTDIR"
echo "PSLOT = $PSLOT"
echo

## initialize
yyyymmdd=`echo $CDATE | cut -c1-8`
hh=`echo $CDATE | cut -c9-10`
yyddd=`date +%y%j -u -d $yyyymmdd`
yyyy=`echo $CDATE | cut -c1-4`
mm=`echo $CDATE | cut -c5-6`
#fv3ic_dir=${ROTDIR}/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}
fv3ic_dir=${ROTDIR}/${CDUMP}.${yyyymmdd}/${hh}/
hpssdir="/NCEPPROD/hpssprod/runhistory/rh$yyyy/$yyyy$mm/$PDY"

## create links in FV3ICS directory
mkdir -p $fv3ic_dir
cd $fv3ic_dir
echo "making link to nemsio files under $fv3ic_dir"

pubsfc_file=${yyddd}${hh}00.${CDUMP}.t${hh}z.sfcanl.nemsio 
sfc_file=`echo $pubsfc_file | cut -d. -f2-`
pubatm_file=${yyddd}${hh}00.${CDUMP}.t${hh}z.atmanl.nemsio 
atm_file=`echo $pubatm_file | cut -d. -f2-`

echo "pubsfc_file:  $pubsfc_file"
echo "pubatm_file:  $pubatm_file"

if [[ -f $PUBDIR/${pubsfc_file} ]]; then
  echo "linking $PUBDIR...."
  ln -fs $PUBDIR/${pubsfc_file} $sfc_file 
  ln -fs $PUBDIR/${pubatm_file} $atm_file 
elif  [[ -f $RETRODIR/${pubsfc_file} ]]; then
  echo "linking $RETRODIR...."
  ln -fs $RETRODIR/${pubsfc_file} $sfc_file
  ln -fs $RETRODIR/${pubatm_file} $atm_file
else
        nfanal=2
	if [[ $CDATE -le "2019061200"  ]]; then
	  fanal[1]="./${CDUMP}.t${cyc}z.atmanl.nemsio"
          fanal[2]="./${CDUMP}.t${cyc}z.sfcanl.nemsio"
        else
	  cd ${ROTDIR}
          fanal[1]="./${CDUMP}.$yyyymmdd/$cyc/${CDUMP}.t${cyc}z.atmanl.nemsio"
          fanal[2]="./${CDUMP}.$yyyymmdd/$cyc/${CDUMP}.t${cyc}z.sfcanl.nemsio"
        fi

        flanal="${fanal[1]} ${fanal[2]}"
        tarpref="gpfs_dell1_nco_ops_com"
        if [ $CDUMP = "gdas" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${CDUMP}.${yyyymmdd}_${cyc}.${CDUMP}_nemsio.tar"
        elif [ $CDUMP = "gfs" ]; then
            tarball="$hpssdir/${tarpref}_gfs_prod_${CDUMP}.${yyyymmdd}_${cyc}.${CDUMP}_nemsioa.tar"
        fi

    # Get initial conditions from HPSS
#    if [ $rc -ne 0 ]; then

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
       # for i in `seq 1 $nfanal`; do
       #     $NMV ${fanal[i]} ${ftanal[i]}
       # done

#    fi

    # If found, exit out
    if [ $rc -ne 0 ]; then
        echo "Unable to obtain operational GFS initial conditions, ABORT!"
        exit 1
    fi

#else
#  echo "missing input files!"
#  exit 1
fi
