#!/bin/ksh -l

# this file archives FV3 ICs to the mass store, /BMC/fim/5year/FV3ICS
#    input is operational GFS initial conditions  

module load hpss
module list

# initialize
#inpDir=/scratch4/BMC/rtfim/rtruns/FV3GFS/FV3ICS
#mssDir=FV3ICS
#CDUMP=gfs
#CASE=C384
#yyyymmddhh=$1
echo "****************************"
echo ICSDIR:   $ICSDIR
echo mssDIR:   $mssDir
echo CDUMP:    $CDUMP
echo CASE:     $CASE
echo DATE:     $yyyymmddhh

# for each directory, archive FV3 ICs to mass store in monthly directories
#    /scratch4/BMC/rtfim/rtruns/FV3ICS/2017111012/gfs/C384/INPUT
echo "in $ICSDIR....."
echo "Archiving ${yyyymmddhh} to mss"
cd $ICSDIR
cmd="htar -cPvf /BMC/fim/5year/${mssDir}/${yyyymmddhh}_${CASE}.tar ${CDUMP}/${CASE}/INPUT/*"
$cmd
status=$?
if [ $status != 0 ] ; then
  printf "Error : [%d] when executing htar command: '$cmd'" $status
  exit $status
fi
