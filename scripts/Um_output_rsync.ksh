#!/bin/ksh
#
arguments=$*
echo "\n=====>  Um_output_rsync.ksh starts: `date` ###########\n"

. r.entry.dot
#
#====> Obtaining the arguments:
eval `cclargs_lite $0 \
     -reps    ""   ""  "[remote source directory]" \
     -repd    ""   ""  "[remote destination directory]" \
     -machs   ""   ""  "[remote source system]" \
     -machd   ""   ""  "[remote destination system]" \
     -attempts  "${attempts:-36}"   "1" "[Number of attempts to try each transfer before giving up]"\
     -sleeptime "${sleeptime:-120}" "0" "[Interval in seconds between transfer attemps]"\
     -_status "ABORT"    "ABORT"    "[return status]"  \
  ++ $arguments`
#
if [ ! "${machs}" -o ! "${machd}" -o ! "${reps}" -o ! "${repd}" ] ; then
  attempts=0
fi
#
nbfiles=`ssh ${machs} -n "cd ${reps} ; ls -l 2> /dev/null | wc -l"`
if [ $nbfiles -le 1 ] ; then
   echo "\n NO FILE TO TRANFER: (Um_xfer_rsync)\n"
   _status=NOFILE
   . r.return.dot
   exit
fi
#
echo "\n File transfer from ${machs}:${reps} to ${machd}:${repd} using rsync\n"
#
attempt=${attempts}
while [ ${attempt} -gt 0 ] ; do
#
  HHi=`date`
  r.rsync -ssh --copy-links ${reps} ${machd}:${repd}
  flag_rcp=$?

  if [ ${flag_rcp} -ne 0 ] ; then
#
    attempt=$(( ${attempt} - 1 ))
#
    if [ ${attempt} -gt 0 ]; then
      echo " Problem with rsync from ${machs}:${reps} at `date`"
      echo " Process sleeps for ${sleeptime} seconds and will retry"
      sleep ${sleeptime}
    else
      echo " Problem with rsync from ${machs}:${reps} after ${attempts} attempts"
      echo " Files will remain on ${machs}"
      attempt=0
    fi
#
  else
#
    repd=${repd}/`basename ${reps}`
    echo "\nContent of destination directory ${repd} on ${machd}: \n"
    ssh ${machd} -n "cd ${repd} ; ls -l"
#
    size_src=`find ${reps}/ -type f -exec ls -l {} \; | awk 'BEGIN{s=0}{s = s + $5}END{printf "%.10g\n",  s / 1048576.}'`
    nf_src=`find ${reps}/ -type f -exec ls -l {} \; | wc -l`

    size_dst=`ssh ${machd} "find ${repd}/ -type f -exec ls -l {} \;" | awk 'BEGIN{s=0}{s = s + $5}END{printf "%.10g\n",  s / 1048576.}'`
    nf_dst=`ssh ${machd} -n "find ${repd}/ -type f -exec ls -l {} \;" | wc -l`

    fract=$(echo "scale=5 ; ($size_src-$size_dst) / $size_dst * 100" | bc -l)
    if [ $fract -lt 0 ] ; then 
      fract=$(echo "scale=5 ; ($size_dst-$size_src) / $size_dst * 100" | bc -l)
    fi
    fract=$(echo "scale=5 ; $fract * 1000" | bc -l)

    tolerance=1

    if [ $nf_src -eq $nf_dst ]   ; then
    if [ $fract -le $tolerance ] ; then
      echo "\n Rsync Transfer started at " $HHi
      echo   " Rsync Transfer ended   at " `date`
      _status=OK
    fi
    fi
    attempt=0
#
  fi
#
done
#
echo "\nUm_output_rsync.ksh ends: "`date`"\n"
. r.return.dot
#
