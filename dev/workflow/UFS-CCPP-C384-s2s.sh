USER=Kate.Zhang


BASEDIR=/scratch4/BMC/gsd-fv3-dev/lzhang/GCAFS/global-workflow-catchem
STMP=/scratch3/NCEPDEV/stmp/$USER/RUNDIRS
IDATE=2016070100
EDATE=2016070100
APP=S2SW
PSLOT=UCS_C384_CCPP
RES=384
GFS_CYC=1
START=cold
COMROT=/scratch4/NCEPDEV/naqfc/Kate.Zhang/fv3gfs/comrot/gcafsv1/COMROOT
EXPDIR=/scratch4/BMC/gsd-fv3-dev/NCEPDEV/global/$USER/fv3gfs/expdir
ICSDIR=$COMROT/$PSLOT


#./setup_expt.py gfs forecast-only --idate $IDATE --edate $EDATE --app $APP --gfs_cyc $GFS_CYC --resdetatmos $RES --pslot $PSLOT --comroot $COMROT --expdir $EXPDIR 

./setup_expt.py gfs forecast-only --app $APP --pslot $PSLOT --idate $IDATE --edate $EDATE --resdetatmos $RES  --comroot $COMROT --expdir $EXPDIR 


./setup_workflow.py $EXPDIR/$PSLOT rocoto

