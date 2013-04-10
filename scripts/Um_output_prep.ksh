#!/bin/ksh
#
arguments=$*
. r.entry.dot

#====> Obtaining the arguments:
eval `cclargs_lite $0 \
     -tskbdir   ""   ""    "[task base directory                ]" \
     -d2z       "0"  "1"   "[Bemol or not                       ]" \
     -dplusp    "0"  "1"   "[combine dynamics and physics output]" \
     -endstep   "0"  "0"   "[Last timestep #                    ]" \
     -prefix    ""   ""    "[Prefix for output files            ]" \
     -listm     ""   ""    "[xfer model listings along          ]" \
     -cfg_file  ""   ""    "[User config file                   ]" \
     -_rep2xfer ""   ""    "[actual directory to transfer       ]" \
     -_status   "ABORT"  "ABORT"  "[return status               ]" \
  ++ $arguments`

echo "\n=====>  Um_output_prep.ksh starts: `date` ###########\n"

# Task structure setup
TASK_BASEDIR=${tskbdir:-XFERMOD}
TASK_BASEDIR=`true_path ${TASK_BASEDIR}`
TASK_INPUT=${TASK_BASEDIR}/input/last_step_${endstep}
TASK_BIN=${TASK_BASEDIR}/bin
TASK_WORK=${TASK_BASEDIR}/work
TASK_OUTPUT=${TASK_BASEDIR}/output

ici=`pwd`
feseri=${TASK_BIN}/FESERI
output_step_rep=${TASK_OUTPUT}/last_step_${endstep}
_rep2xfer=$output_step_rep

if [ "${listm}" ] ; then
  mkdir -p ${output_step_rep}
  lalistetomv=`ls ${listm}* 2> /dev/null | xargs`
  if [ -n "$lalistetomv" ] ; then
    mv ${lalistetomv} ${output_step_rep} 2> /dev/null
  fi
fi

nbfiles=`find -L ${TASK_INPUT} -type f | wc -l`
echo "##### UM_TIMING OUTPUT -PREP_1find-: "`date`
laliste="dm dp dh pm pp ph"

if [ ${nbfiles} -gt 0 ] ; then

  mkdir -p ${output_step_rep}
  flag_err=0
  echo "D2Z starts ${nbfiles}: "`date`
  d2z_error=0

  for i in ${laliste} ; do
#
  f2t=${i}\*
  time nf2t=`find -L ${TASK_INPUT} -name "${i}[0-9]*" -type f | wc -l`
  if [ ${nf2t} -gt 0 ] ; then
    echo "\n Processing ${f2t} "
    pivot_rept=tmp_d2z
    mkdir -p ${pivot_rept}
    time find -L ${TASK_INPUT} -name "${i}[0-9]*" -type f -exec mv {} ${pivot_rept} \;
    echo "##### UM_TIMING OUTPUT -PREP_2find1mv $i $nf2t: "`date`
    if [ ${d2z} -gt 0 ] ; then
      echo "\n ${TASK_BIN}/Um_output_d2z.ksh -rep ${pivot_rept}"
      time ${TASK_BIN}/Um_output_d2z.ksh -rep ${pivot_rept}
      if [ $? -ne 0 ] ; then
        echo "\n Error in d2z job \n"
        let d2z_error=${d2z_error}+1
      fi
      echo "##### UM_TIMING OUTPUT -PREP_bemol: "`date`
    fi
    cd ${pivot_rept}
    for file in * ; do
      mv ${file} ${output_step_rep}/${prefix}${file}
    done
    cd ${ici}
    rmdir ${pivot_rept}
  fi
  done
  echo "\nD2Z ends: `date`\n"
  flag_err=d2z_error

  if [ ${flag_err} -eq 0 ] ; then
  if [ -s ${TASK_INPUT}/time_series.bin ] ; then
    cp ${TASK_INPUT}/time_series.bin .
    echo "\n ${feseri} -iserial time_series.bin -omsorti time_series.fst \n"
    ${feseri} -iserial time_series.bin -omsorti time_series.fst 1> /dev/null
    if [ $? -ne 0 ]; then
      echo "\n ${feseri} aborted \n"
      /bin/rm -f time_series.fst
      flag_err=1
    else
      mv time_series.fst ${output_step_rep}
      /bin/rm -f ${TASK_INPUT}/time_series.bin
    fi
  fi
  /bin/rm -f time_series.bin
  fi

  if [ ${flag_err} -eq 0 ] ; then
    find -L ${TASK_INPUT} -type f -name "zonaux_*" -exec mv {} $output_step_rep \;

    if [ -d ${TASK_INPUT}/casc ] ; then
      mv ${TASK_INPUT}/casc ${output_step_rep}
    fi

    find -L ${TASK_INPUT} -type f -exec mv {} $output_step_rep \;
  fi

  cd ${output_step_rep}

  if [ ${flag_err} -eq 0 ] ; then
    if [ ${dplusp} -gt 0 ] ; then
      dmliste=`find ./ -name "${prefix}dm[0-9]*" | sed 's/.*_//' | xargs`
      dpliste=`find ./ -name "${prefix}dp[0-9]*" | sed 's/.*_//' | xargs`
      dhliste=`find ./ -name "${prefix}dh[0-9]*" | sed 's/.*_//' | xargs`
      pmliste=`find ./ -name "${prefix}pm[0-9]*" | sed 's/.*_//' | xargs`
      ppliste=`find ./ -name "${prefix}pp[0-9]*" | sed 's/.*_//' | xargs`
      phliste=`find ./ -name "${prefix}ph[0-9]*" | sed 's/.*_//' | xargs`
      echo "\nDPLUSP starts: "`date`
      time ${TASK_BIN}/Um_output_dplusp.ksh -dm $dmliste -dp $dpliste -dh $dhliste -pm $pmliste -pp $ppliste -ph $phliste  1> scrap$$
      /bin/rm -f scrap$$
      echo "\nDPLUSP ends: "`date`
    fi
    echo "##### UM_TIMING OUTPUT -PREP_dplusp: "`date`
    _status='OK'
    nbfiles=`find -L ./ -type f | wc -l`
    echo "\n FINAL # of files after Um_output_prep: ${nbfiles}\n"
  else
    echo "ERRORS found with d2z in ${TASK_BIN}/Um_output_d2z.ksh - ABORT"
  fi

else

  echo "\n No files to process from ${TASK_INPUT}\n"
  _status='NOFILE'

fi

echo "\n=====>  Um_output_prep.ksh ends: `date` ###########\n"

# End of task
. r.return.dot



