USER=Jian.He


BASEDIR=/scratch4/BMC/rcm1/jhe/ufschem/global-workflow-am4
STMP=/scratch3/BMC/rcm2/jhe/ufschem/RUNDIRS

IDATE=2022123100
EDATE=2023010200
SDATE_GFS=2023010100

APP=ATM 
PSLOT=C96L128_CYCL_AM4
RES=96
START=cold

COMROT=/scratch3/BMC/rcm2/jhe/ufschem/COMROOT
EXPDIR=/scratch3/BMC/rcm2/jhe/ufschem/EXPDIR
ICSDIR=/scratch4/BMC/rcm1/jhe/ufschem/inputdata/FV3ICS/C96L128

cd "${BASEDIR}/dev/workflow"

./setup_expt.py gfs cycled \
    --app "${APP}" \
    --pslot "${PSLOT}" \
    --idate "${IDATE}" \
    --edate "${EDATE}" \
    --sdate_gfs "${SDATE_GFS}" \
    --interval 24 \
    --resdetatmos "${RES}" \
    --start "${START}" \
    --icsdir "${ICSDIR}" \
    --comroot "${COMROT}" \
    --expdir "${EXPDIR}" \
    --yaml ../parm/config/gfs/yaml/am4_offline_cycled.yaml

./setup_workflow.py $EXPDIR/$PSLOT rocoto

