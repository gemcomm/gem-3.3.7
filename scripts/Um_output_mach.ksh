#!/bin/ksh
#
arguments=$*
. r.entry.dot
#
#====> Obtaining the arguments:
eval `cclargs_lite $0 \
     -attempts   "${attempts:-36}"   "1" "[Number of attempts to try each transfer before giving up]"\
     -sleeptime  "${sleeptime:-120}" "0" "[Interval in seconds between transfer attemps]"\
     -_status "ABORT"    "ABORT"    "[return status]"  \
  ++ $arguments`
#
attempt=${attempts}
while [ ${attempt} -gt 0 ]; do
#
#====> Check that ${src_mach} is available
#
  ssh ${src_mach} -n ls 1> /dev/null 2>&1
  src_mach_status=$?
#
#====> Check that ${dest_mach} is available
#
  ssh ${dest_mach} -n ls 1> /dev/null 2>&1
  dest_mach_status=$?
  #
  if [ ${src_mach_status}  -ne 0 -o \
       ${dest_mach_status} -ne 0 ]; then
    #
    attempt=$(( ${attempt} - 1 ))
    if [ ${attempt} -gt 0 ]; then
      echo " Problem with remote systems availability at `date`"
      echo " ${src_mach} status = ${src_mach_status}"
      echo " ${dest_mach} status = ${dest_mach_status}"
      echo " Process sleeps for ${sleeptime} seconds and will retry"
      sleep ${sleeptime}
    else
      echo "\n At least one remote system NOT available at `date`\n"
      echo " Work should be re-scheduled at a later time\n"
      mail ${USER} << eofmail
 
      WARNING *** WARNING *** WARNING *** WARNING *** WARNING *** WARNING
 
      At least one remote system NOT available at `date`
      ${src_mach} or ${dest_mach}
 
      This work will have to be re-scheduled at a later time...
 
      WARNING *** WARNING *** WARNING *** WARNING *** WARNING *** WARNING
 
eofmail
      attempt=0
    fi
    #
  else
    #
    if [ ${attempt} -ne ${attempts} ]; then
      echo "\n Both remote systems available at `date`\n"
    fi
    _status=OK
    attempt=0
    #
  fi
  #
done
. r.return.dot
#
