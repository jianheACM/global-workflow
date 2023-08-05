USER=Jian.He


BASEDIR=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/develop/global-workflow
STMP=/scratch1/BMC/rcm2/jhe/model_output/ufs-chem
CONFIGDIR=$BASEDIR/parm/config
IDATE=2016071500
EDATE=2016071600
APP=ATM
PSLOT=P8_UFS_C96_CATChem_RACM
RES=96
GFS_CYC=1
COMROT=/scratch1/BMC/rcm2/jhe/model_output/ufs-chem/comrot
EXPDIR=/scratch2/BMC/rcm1/jhe/fv3/ufs-chem/expdir
ICSDIR=$COMROT/$PSLOT

./setup_expt.py forecast-only --app $APP --pslot $PSLOT --configdir $CONFIGDIR --idate $IDATE --edate $EDATE --res $RES --gfs_cyc $GFS_CYC --comrot $COMROT --expdir $EXPDIR --icsdir $ICSDIR 


./setup_xml.py $EXPDIR/$PSLOT


