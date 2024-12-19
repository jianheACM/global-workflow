#! /usr/bin/env bash

source "$HOMEgfs/ush/preamble.sh"

## this script makes links to FV3GFS netcdf files under /public 
##   /home/rtfim/UFS_CAMSUITE/FV3GFSrun/FV3ICS/YYYYMMDDHH/gfs
##     gfs.tHHz.sfcanl.nc -> /public/data/grids/gfs/netcdf/YYDDDHH00.gfs.tHHz.sfcanl.nc
##     gfs.tHHz.atmanl.nc -> /public/data/grids/gfs/netcdf/YYDDDHH00.gfs.tHHz.atmanl.nc

echo
echo "CDATE = $CDATE"
echo "CDUMP = $CDUMP"
echo "COMPONENT = $COMPONENT"
echo "ICSDIR = $ICSDIR"
echo "PUBDIR = $PUBDIR"
echo "RETRODIR = $RETRODIR"
echo "ROTDIR = $ROTDIR"
echo "PSLOT = $PSLOT"
echo

## initialize
yyyymmdd=`echo $CDATE | cut -c1-8`
hh=`echo $CDATE | cut -c9-10`
yyddd=`date +%y%j -u -d $yyyymmdd`
fv3ic_dir=${ROTDIR}/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}

## create links in FV3ICS directory
mkdir -p $fv3ic_dir
cd $fv3ic_dir
echo "making link to netcdf files under $fv3ic_dir"

pubsfc_file=${yyddd}${hh}00.${CDUMP}.t${hh}z.sfcanl.nc
sfc_file=`echo $pubsfc_file | cut -d. -f2-`
pubatm_file=${yyddd}${hh}00.${CDUMP}.t${hh}z.atmanl.nc
atm_file=`echo $pubatm_file | cut -d. -f2-`

echo "pubsfc_file:  $pubsfc_file"
echo "pubatm_file:  $pubatm_file"

if  [[ -f $RETRODIR/${pubatm_file} ]]; then
  echo "linking $RETRODIR...."
  echo "pubsfc_file:  $pubsfc_file"
  echo "pubatm_file:  $pubatm_file"
  ln -fs $RETRODIR/${pubsfc_file} $sfc_file
  ln -fs $RETRODIR/${pubatm_file} $atm_file 
elif [[ -f $PUBDIR/${pubatm_file} ]]; then
  echo "linking $PUBDIR...."
  ln -fs $PUBDIR/${pubsfc_file} $sfc_file
  ln -fs $PUBDIR/${pubatm_file} $atm_file
elif  [[ -f $EMCDIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}/${atm_file} ]]; then
  echo "linking $EMCDIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}..."
  echo "sfc_file:  $sfc_file"
  echo "atm_file:  $atm_file"
  ln -s $EMCDIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}/${sfc_file}
  ln -s $EMCDIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}/${atm_file}
elif  [[ -f $RETRODIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}/${atm_file} ]]; then
  echo "linking $RETRODIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}..."
  echo "sfc_file:  $sfc_file"
  echo "atm_file:  $atm_file"
  ln -s $RETRODIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}/${sfc_file}
  ln -s $RETRODIR/${CDUMP}.${yyyymmdd}/${hh}/${COMPONENT}/${atm_file}
else
  echo "missing input files!"
  exit 1
fi
