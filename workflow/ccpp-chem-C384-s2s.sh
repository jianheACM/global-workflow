USER=Kate.Zhang


BASEDIR=/scratch2/BMC/gsd-fv3-dev/lzhang/UFS-dev/global-workflow-s2s
STMP=/scratch1/NCEPDEV/stmp2/$USER/RUNDIRS
IDATE=2016070100
EDATE=2016070100
APP=S2SW
PSLOT=CAT_C384_CCPP
RES=384
GFS_CYC=1
START=cold
COMROT=/scratch1/BMC/gsd-fv3-dev/NCEPDEV/global/$USER/fv3gfs/comrot
EXPDIR=/scratch2/BMC/gsd-fv3-dev/NCEPDEV/global/$USER/fv3gfs/expdir
ICSDIR=$COMROT/$PSLOT


#./setup_expt.py gfs forecast-only --idate $IDATE --edate $EDATE --app $APP --gfs_cyc $GFS_CYC --resdetatmos $RES --pslot $PSLOT --comroot $COMROT --expdir $EXPDIR 

./setup_expt.py gfs forecast-only --app $APP --pslot $PSLOT --idate $IDATE --edate $EDATE --resdetatmos $RES --gfs_cyc $GFS_CYC --comroot $COMROT --expdir $EXPDIR 


./setup_xml.py $EXPDIR/$PSLOT

