#!/bin/ksh

arguments=$*
. r.entry.dot

eval `cclargs_lite $0 \
  -barrier  "0"            "0"         "[DO NOT run binary         ]" \
  -manoutp  "1"            "1"         "[Manage model output       ]" \
  -_status  "ABORT"        "ABORT"     "[return status             ]" \
  -_endstep ""             ""          "[last time step performed  ]" \
  -_npe     "1"            "1"         "[number of subdomains      ]" \
  ++ $arguments`

set ${SETMEX:-+ex}

cd ${TASK_WORK}

REPGEOPHY=${TASK_INPUT}/LAM_geophy
if [ -L ${REPGEOPHY} ] ; then
  prefixg=$(echo $(basename `ls -L ${REPGEOPHY}/*_gfilemap.txt 2> /dev/null`) | sed 's/_gfilemap\.txt//')
  echo ${prefixg##*/} > geophy_fileprefix_for_LAM
fi

# Task-specific setup
nml=model_settings.nml
npx=`${TASK_BIN}/Um_fetchnml.ksh npex $nml`
npy=`${TASK_BIN}/Um_fetchnml.ksh npey $nml`
npx=${npx:-1}
npy=${npy:-1}
let _npe=npx*npy
echo localhost $_npe

for i in `find $TASK_INPUT/ -name "BUSPER4spinphy*" 2> /dev/null` ; do
  tar xvf $i
done

. r.call.dot ${TASK_BIN}/Um_cmclog.ksh -mod 1

export CMC_LOGFILE=$_CMC_LOGFILE

# Run executable (main)
echo "Running ${TASK_BIN}/ATM_MOD.Abs on $_npe ($npx x $npy) PEs:"
if [ $barrier -gt 0 ] ; then
  echo GEM_Mtask 1
  r.barrier
  echo GEM_Mtask 2
  r.barrier
  echo "\n =====> Um_model.ksh CONTINUING after last r.barrier\n"
else
  echo "${TASK_BIN}/r.mpirun -pgm ${TASK_BIN}/ATM_MOD.Abs -npex $npx -npey $npy"
  echo OMP_NUM_THREADS=$OMP_NUM_THREADS
  ${TASK_BIN}/r.mpirun -pgm ${TASK_BIN}/ATM_MOD.Abs -npex $npx -npey $npy
fi

echo "##### UM_TIMING Um_model -MAINDM-: "`date`
. r.call.dot ${TASK_BIN}/Um_cmclog.ksh -mod 2 -CMC_LOGFILE $_CMC_LOGFILE

export CMC_LOGFILE=$_CMC_LOGFILE

# Status update in output directory
cd $TASK_OUTPUT
status_file=status_mod.dot
if [ -s ${status_file} ] ; then
  . ${status_file} ; /bin/rm -f ${status_file}
fi

# Manage model output
if [ $manoutp -gt 0 ] ; then

cd $TASK_WORK
find ./ -type f -name "[a-zA-Z][a-zA-Z][0-9]*-[0-9]*-[0-9]*_[0-9]*" -exec mv {} $TASK_OUTPUT \;
errmv=$?
echo "##### UM_TIMING Um_model -FIRSTMV-: "`date`

cnt=`find ./000-000 -name "BUSPER4spinphy*" 2> /dev/null | wc -l`
if [ $cnt -gt 0 ] ; then
  fn=`ls 000-000/BUSPER4spinphy*`
  fn=`basename $fn`
  tar cvf $TASK_OUTPUT/${fn}.tar [0-9]*/BUSPER4spinphy*
  /bin/rm -f [0-9]*/BUSPER4spinphy*
fi
if [ $errmv -eq 0 -a "$_status" = "ED" ] ; then
  find ./ -type f -name "time_series.bin" -exec mv {} $TASK_OUTPUT \;
  find ./ -type f -name "zonaux_*"        -exec mv {} $TASK_OUTPUT \;
  for i in [0-9]* ; do
    if [ -d $i ] ; then
      find ./ -type f -name "*_0000.hpm*" -exec mv {} $TASK_OUTPUT \;
      /bin/rm -rf $i
    fi
  done
  if [ ! -s ${TASK_OUTPUT}/time_series.bin ] ; then
    echo "${TASK_OUTPUT}/time_series.bin is empty - will be removed"
    ls -l ${TASK_OUTPUT}/time_series.bin 2> /dev/null
    /bin/rm -f ${TASK_OUTPUT}/time_series.bin
  fi
fi

fi 

# End of task
. r.return.dot
