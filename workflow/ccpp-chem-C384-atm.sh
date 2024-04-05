USER=Kate.Zhang


BASEDIR=/scratch2/BMC/gsd-fv3-dev/lzhang/UFS-dev/global-workflow
STMP=/scratch1/NCEPDEV/stmp2/$USER/RUNDIRS
IDATE=2016071500
EDATE=2016071500
APP=ATM
PSLOT=AUFS_C384_CCPP
RES=384
GFS_CYC=1
START=cold
COMROT=/scratch1/BMC/gsd-fv3-dev/NCEPDEV/global/$USER/fv3gfs/comrot
EXPDIR=/scratch2/BMC/gsd-fv3-dev/NCEPDEV/global/$USER/fv3gfs/expdir
ICSDIR=$COMROT/$PSLOT


./setup_expt.py gfs forecast-only --idate $IDATE --edate $EDATE --app $APP --gfs_cyc $GFS_CYC --resdetatmos $RES --pslot $PSLOT --comroot $COMROT --expdir $EXPDIR 


./setup_xml.py $EXPDIR/$PSLOT

