USER=Congmeng.Lyu


BASEDIR=/scratch4/BMC/rcm1/clyu/UFS-Chem_v1
STMP=/scratch3/BMC/rcm2/clyu/UFS-Chem_v1/RUNDIRS
IDATE=2026040100
EDATE=2026103100
APP=ATM
PSLOT=UFS_C96_CATChem_AM4_AIRMAPS
RES=96
GFS_CYC=1
START=cold
COMROT=/scratch3/BMC/rcm2/clyu/UFS-Chem_v1/comrot
EXPDIR=/scratch3/BMC/rcm2/clyu/UFS-Chem_v1/expdir
ICSDIR=$COMROT/$PSLOT


./setup_expt.py gfs forecast-only --idate $IDATE --edate $EDATE --app $APP --gfs_cyc $GFS_CYC --resdetatmos $RES --pslot $PSLOT --comroot $COMROT --expdir $EXPDIR 


./setup_xml.py $EXPDIR/$PSLOT

