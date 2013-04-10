#!/bin/ksh

arguments=$*
. r.entry.dot

eval `cclargs_lite $0 \
  -mod           "0"    "0"    "[]" \
  -_CMC_LOGFILE  ""     ""     "[cmc log file]" \
  ++ $arguments`

if [ -z "${UM_EXEC_cmclog}" -o $mod -eq 0 ] ; then
  . r.return.dot
  exit
fi

TRUE_CMCLOG=`true_path ${UM_EXEC_cmclog}`

if [ $mod -eq 1 ] ; then

  _CMC_LOGFILE=`true_path ./`/`basename ${UM_EXEC_cmclog}`
  if [ -s ${UM_EXEC_cmclog} ] ; then
    if [ "${TRUE_CMCLOG}" != "${_CMC_LOGFILE}" ] ; then
      echo "Um_cmclog.ksh: cp ${UM_EXEC_cmclog} ${_CMC_LOGFILE}"
      cp ${UM_EXEC_cmclog} ${_CMC_LOGFILE}
    fi
  fi

fi

if [ $mod -eq 2 ] ; then

  if [ -n "${_CMC_LOGFILE}" ] ; then
  if [ -s ${_CMC_LOGFILE}   ] ; then
    if [ "${TRUE_CMCLOG}" != "${_CMC_LOGFILE}" ] ; then
      echo "Um_cmclog.ksh: cp ${_CMC_LOGFILE} ${UM_EXEC_cmclog}"
      cp ${_CMC_LOGFILE} ${UM_EXEC_cmclog}
    fi
  fi
  fi
  _CMC_LOGFILE=''

fi

. r.return.dot

