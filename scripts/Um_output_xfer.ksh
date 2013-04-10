#!/bin/ksh
#
arguments=$*

echo "\n=====>  Um_output_xfer.ksh starts: `date` ###########\n"

#====> Obtaining the arguments:
eval `cclargs_lite $0 \
     -s   ""   ""     "[source     ]" \
     -d   ""   ""     "[destination]" \
  ++ $arguments`
#

d=`echo $d | sed 's/:/ /g'`
#
export src_mach=${s%% *}
src_rept=${s##* }
export dest_mach=${d%% *}
dest_rept=${d##* }
#
REP=XFERMOD_upload
RUNMACH=${REP}/bin/Um_output_mach.ksh
if [ ! -x "${RUNPREP}" ] ; then
  RUNMACH=""
fi
RUNSYNC=${REP}/bin/Um_output_rsync.ksh
if [ ! -x ${RUNSYNC} ] ; then
  RUNSYNC=""
fi

. r.call.dot ${RUNMACH:-Um_output_mach.ksh} -attempts 2
if [ "$_status" = "ABORT" ] ; then
  echo "\n ----------- ABORT ---------\n" ; exit 5
fi

nbfiles=`ssh ${src_mach} -n ls -x ${src_rept} | wc -w`
_status=ABORT
/bin/rm -f  status_xfer

if [ ${nbfiles} -eq 0 ] ; then
#
  echo "\n No file to transfer from ${src_mach}:${src_rept}\n"
  _status='NOFILE'
#
else
#
  _status=ABORT
  CHECKFS=`which Um_checkfs.ksh`
  CHECKFS=`true_path $CHECKFS`
  flag1=`ssh ${dest_mach} -n "mkdir -p ${dest_rept} ; cd $dest_rept 2> /dev/null; echo \$?"`
  flag2=`ssh ${dest_mach} -n "$CHECKFS ${dest_rept} 1> /dev/null 2> /dev/null   ; echo \$?"`

  if [ $flag1 -eq 0 -a $flag2 -eq 0 ] ; then
    repxfer=${src_rept}_$$
    /bin/mv ${src_rept} ${repxfer}
    . r.call.dot ${RUNSYNC:-Um_output_rsync.ksh} -machs ${src_mach} -reps ${repxfer} \
                             -machd ${dest_mach} -repd ${dest_rept} -attempts 2
    /bin/mv ${repxfer} ${src_rept}
  else
    _status='ABORT'
  fi

  if [ "$_status" = "OK" ] ; then
     echo " Rsync Transfer succeeded at" `date`
     echo "\n All pending transfers succeeded"
     echo "\n Removing ${src_rept} on ${src_mach} ...."
     ssh ${src_mach} -n /bin/rm -rf  ${src_rept}
     echo "\n Moving data from ${dest_rept} on ${dest_mach} ....\n"
     echo ". /users/dor/armn/mod/ovbin/sm5 -version ${MODEL_VERSION} ; Um_output_lastmv.ksh ${dest_rept} `basename $repxfer` " | ssh $dest_mach bash --login
     echo "\n Moving data DONE...\n"
  fi
fi
#
echo "status_xfer=$_status" > status_xfer
#
echo "\nUm_output_xfer.ksh ends: "`date`"\n"
