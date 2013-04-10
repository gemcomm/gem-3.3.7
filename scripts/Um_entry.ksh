#!/bin/ksh

arguments=$*
. r.entry.dot

eval `cclargs_lite $0 \
  -_status    "ABORT"     "ABORT"     "[return status   ]"   \
  ++ $arguments`

set ${SETMEX:-+ex}

cd ${TASK_WORK}

if [ -d ${TASK_INPUT}/INREP ] ; then
  ls -1 ${TASK_INPUT}/INREP > liste_inputfiles_for_LAM
  cat liste_inputfiles_for_LAM
fi

. r.call.dot ${TASK_BIN}/Um_cmclog.ksh -mod 1
export CMC_LOGFILE=$_CMC_LOGFILE

# Run executable (entry)
$TASK_BIN/ATM_NTR.Abs

. r.call.dot ${TASK_BIN}/Um_cmclog.ksh -mod 2 -CMC_LOGFILE $_CMC_LOGFILE

# Perform status update in output directory
cd $TASK_OUTPUT
status_file=status_ent.dot
if [ -s ${status_file} ] ; then
  . ${status_file} ; /bin/rm -f ${status_file}
fi

# End of task
. r.return.dot
