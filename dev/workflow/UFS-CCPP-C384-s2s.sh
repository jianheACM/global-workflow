USER=Jian.He


BASEDIR=/scratch4/BMC/rcm1/jhe/ufschem/global-workflow-am4
STMP=/scratch3/BMC/rcm2/jhe/ufschem/RUNDIRS
IDATE=2016080100
EDATE=2016080100
APP=S2SW
PSLOT=C384_CCPP_CPL
RES=384
GFS_CYC=1
START=cold
COMROT=/scratch3/BMC/rcm2/jhe/ufschem/COMROOT
EXPDIR=/scratch3/BMC/rcm2/jhe/ufschem/EXPDIR
ICSDIR=$COMROT/$PSLOT


#./setup_expt.py gfs forecast-only --idate $IDATE --edate $EDATE --app $APP --gfs_cyc $GFS_CYC --resdetatmos $RES --pslot $PSLOT --comroot $COMROT --expdir $EXPDIR 

./setup_expt.py gfs forecast-only --app $APP --pslot $PSLOT --idate $IDATE --edate $EDATE --resdetatmos $RES  --comroot $COMROT --expdir $EXPDIR 


./setup_workflow.py $EXPDIR/$PSLOT rocoto

