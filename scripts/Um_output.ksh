#!/bin/ksh
#
script=${0##*/}
args="$@"

arguments=$*

#====> Obtaining the arguments:
eval `cclargs_lite $0 \
     -execdir    ""    ""    "[Execution directory    ]" \
     -dotcfg     ""    ""    "[Dotable config file    ]" \
     -cfg_file   ""    ""    "[User config file       ]" \
     -job        ""    ""    "[jobname                ]" \
     -listing    ""    ""    "[listing directory      ]" \
     -ppid       ""    ""    "[ppid                   ]" \
     -endstepno  "0"   "0"   "[Last timestep #        ]" \
     -mod_status "RS"  "RS"  "[status of Um_runmod.ksh]" \
     -listm      ""    ""    "[xfer model listings    ]" \
     -forceit    "0"   "1"   "[force execution        ]" \
     -phyversion ""    ""    "[physics package version]" \
  ++ $arguments`
#

echo "\n=====>  Um_output.ksh starts: `date` ###########\n"

Um_checkfs.ksh $execdir
if [ $? -ne 0 ] ; then exit 1 ; fi

cd $execdir

. $dotcfg

if [ ! "$UM_EXEC_xfer" ] ; then
  echo "\n No file xfer requested\n"
  exit 0
fi

# Set task end step number
if [ $endstepno -gt 0 ] ; then
  endstep=`echo ${endstepno} | sed 's/^0*//'`
else
  endstep=0
fi

repoutput=RUNMOD/output
replast=XFERMOD_upload/input/last_step_$endstep
mkdir -p ${replast}

MV=${TMPDIR}/mv$$
cat > ${MV} << EOF
f=${repoutput}/\$1
if [ ! -d \${f} ] ; then
  mv \${f} $replast
else
  echo \${f} is a directory
fi
EOF
chmod 755 ${MV}

echo "\nMove files from ${repoutput} in $replast"
ls ${repoutput} | xargs -l1 ${MV}
echo "##### UM_TIMING Um_output MV2LAST-: "`date`
/bin/rm -f ${MV}

# UM_EXEC_casc=0 ==> leave casc in ${repoutput} (do nothing)
# UM_EXEC_casc=1 ==> move casc in $replast for transfer 
# UM_EXEC_casc=2 ==> transfer casc and leave a copy in ${repoutput}

if [ ${UM_EXEC_casc:-1} -gt 0 ] ; then
  if [ `ls -L ${repoutput}/casc 2> /dev/null | wc -l` -gt 0 ] ; then
    if [ ${UM_EXEC_casc:-1} -gt 1 ] ; then
      echo "\nCopy directory ${repoutput}/casc from ${repoutput} in $replast"
      cp -r ${repoutput}/casc $replast
    else
      echo "\nMove directory ${repoutput}/casc from ${repoutput} in $replast"
      mv ${repoutput}/casc $replast
    fi
  fi
fi

nf2xfer=`find -L ${replast} -type f | wc -l`
echo "\n=====> $nf2xfer files in directory ${replast}"
echo "##### UM_TIMING Um_output -LASTFIND-: "`date`

if [ $nf2xfer -ge 1 -o $forceit -ge 1 ] ; then

# Task structure setup
rep=XFERMOD
mkdir -p ${rep}
export TASK_BASEDIR=`true_path $rep`
TASK_INPUT=${TASK_BASEDIR}/input
TASK_BIN=${TASK_BASEDIR}/bin
TASK_WORK=${TASK_BASEDIR}/work
TASK_OUTPUT=${TASK_BASEDIR}/output

if [ -n "$phyversion" ] ; then
#  main_FESERI=${ARMNLIB}/modeles/PHY/v_${phyversion}/bin/${BASE_ARCH}/feseri_${BASE_ARCH}_${phyversion}.Abs
#  main_FESERI=${ARMNLIB}/modeles/PHY/v_4.7.2/bin/${BASE_ARCH}/feseri_${BASE_ARCH}_4.7.2.Abs
  main_FESERI=$rpnphy/v_${phyversion}/bin/${BASE_ARCH}/feseri_${BASE_ARCH}_${phyversion}.Abs
fi
main_FESERI=${main_FESERI:-ls}

# Generate configuration file on-the-fly if not provided
CFGFILE=''
if [ -n "$cfg_file" ] ; then
  if [ -s $cfg_file ] ; then
    echo "Using config file: $cfg_file"
    CFGFILE=`true_path $cfg_file`
  fi
else
  PREP_cfg='# Um_output_prep.ksh   '`which Um_output_prep.ksh 2>/dev/null`
  XFER_cfg='# Um_output_xfer.ksh   '`which Um_output_xfer.ksh 2>/dev/null`
  D2Z_cfg='# Um_output_d2z.ksh    '`which Um_output_d2z.ksh 2>/dev/null`
  DPLUSP_cfg='# Um_output_dplusp.ksh '`which Um_output_dplusp.ksh 2>/dev/null`
  MACH_cfg='# Um_output_mach.ksh   '`which Um_output_mach.ksh 2>/dev/null`
  RSYNC_cfg='# Um_output_rsync.ksh  '`which Um_output_rsync.ksh 2>/dev/null`
  SERI_cfg="# FESERI      $main_FESERI"
  INDATA_cfg="# last_step_${endstep} ::PWD::/last_step_::endstep::"
  DOTCFG_cfg="# configexp.cfg       ${dotcfg}"
  CFGFILE=$TMPDIR/xfer$$.cfg
  cat > $CFGFILE <<EOF
#############################################
# <input>
${INDATA_cfg}
${DOTCFG_cfg}
# </input>
# <executables>
${PREP_cfg}
${XFER_cfg}
${D2Z_cfg}
${DPLUSP_cfg}
${MACH_cfg}
${RSYNC_cfg}
${SERI_cfg}
# </executables>
# <output>
# </output>
#############################################
EOF
fi

echo "### Content of config file to TASK_SETUP ####"
cat $CFGFILE 2>/dev/null

echo "\n##### EXECUTING TASK_SETUP #####"
/bin/rm -rf ${TASK_BASEDIR}/.setup
${TASK_SETUP:-task_setup-0.7.7.py} -f $CFGFILE --base $TASK_BASEDIR
if [ $? -ne 0 ] ; then exit 1 ; fi
echo "\n#############################################\n"
/bin/rm -f $CFGFILE

cd ${TASK_WORK}

jobname=${job:-task_X}${endstep}
lajob=${jobname}_job
touch ${lajob}
lajob=`true_path ${lajob}`

cat > ${jobname} << EOF
#!/bin/sh
#
set +x
echo "##### UM_TIMING OUTPUT -BEGIN-: "\`date\`
echo "\n######################################################"
echo "########### USER'S JOB STARTS HERE - XFER  ###########"
echo "########### soumet_lajob ${lajob}"
echo "######################################################\n"
#
. /users/dor/armn/mod/ovbin/sm5 -version ${MODEL_VERSION}
#
set -ex

Um_checkfs.ksh ${TASK_WORK}

cd ${TASK_WORK}

. ${TASK_INPUT}/configexp.cfg

RUNPREP=${TASK_BIN}/Um_output_prep.ksh
if [ ! -x \${RUNPREP} ] ; then
  RUNPREP=""
fi
RUNXFER=${TASK_BIN}/Um_output_xfer.ksh
if [ ! -x \${RUNXFER} ] ; then
  RUNXFER=""
fi

. r.call.dot \${RUNPREP:-${TASK_BIN}/Um_output_prep.ksh} \
  -tskbdir ${TASK_BASEDIR}                               \
  -d2z \${UM_EXEC_d2z:-0} -dplusp \${UM_EXEC_dplusp:-0}  \
  -prefix \${UM_EXEC_prefix} -listm ${listm} -endstep ${endstep}
STATUS_prep=\$_status

if [ "\$STATUS_prep" != "ABORT" ] ; then
  
  echo ". /users/dor/armn/mod/ovbin/sm5 -version ${MODEL_VERSION} ; Um_checkfs.ksh ${TASK_WORK} ;\
          if [ \$? -ne 0 ] ; then exit 1 ; fi ; cd ${TASK_WORK}            ;\
          \${RUNXFER:-${TASK_BIN}/Um_output_xfer.ksh}                   \
          -s ${TRUE_HOST}:\${_rep2xfer}                                 \
          -d \${UM_EXEC_xfer}"    | ssh ${TRUE_HOST} bash --login
  STATUS_xfer='ABORT'
  if [ -s status_xfer ] ; then
    . status_xfer
    STATUS_xfer=\$status_xfer
  fi
  echo STATUS_xfer=\$STATUS_xfer
  if [ "\$STATUS_xfer" != "ABORT" ] ; then
    if [ "${mod_status}" = "ED" ] ; then
      tailjob=${TASK_BASEDIR}_upload/input/tailjob_X
      if [ -s \${tailjob} ] ; then
        echo "\n LAUNCHING "\${tailjob}"\n"
        echo "soumet_lajob \${tailjob}" | ssh ${TRUE_HOST} bash --login
       fi
    fi
  else
    cat > unmail << eofmail	 
    Problem with Um_output_xfer.ksh

    YOU SHOULD TRY TO EXECUTE THE COMMAND:
    $script $args -forceit 
    on ${TRUE_HOST}
    OR DEAL OTHERWISE WITH FILES IN 
    ${TRUE_HOST}:\${_rep2xfer}
    IN ORDER TO EMPTY THIS DIRECTORY
       =====> AS SOON AS POSSIBLE. <=====
eofmail
    mail -s "Problem with Um_output_xfer.ksh" $USER < unmail
    /bin/rm unmail
  fi
else
    cat > unmail << eofmail	 
    Problem with Um_output_prep.ksh

    YOU SHOULD TRY TO EXECUTE THE COMMAND:
    $script $args -forceit
    on ${TRUE_HOST}
    OR DEAL OTHERWISE WITH FILES IN 
    ${TRUE_HOST}:${TASK_BASEDIR}/input/last_step_${endstep}
    IN ORDER TO EMPTY THIS DIRECTORY
       =====> AS SOON AS POSSIBLE. <=====
eofmail
    mail -s "Problem with Um_output_prep.ksh" $USER < unmail
    /bin/rm unmail
fi

echo "##### UM_TIMING OUTPUT -END  -: "\`date\`
EOF
chmod 755 ${jobname}

cputime=3600
cmemory=500000
listing=${listing:-${HOME}/listings}
if [ -d $listing/${BACKEND_mach} -o -L $listing/${BACKEND_mach} ] ; then
  listing=$listing/${BACKEND_mach}
fi

ord_soumet ${jobname} -mach ${TRUE_HOST}  -t  ${cputime} -cm ${cmemory} \
                      -listing ${listing} -jn ${jobname} -ppid ${ppid}  \
                      -nosubmit

/bin/mv lajob.tar ${lajob}
soumet_lajob ${lajob}

else

  echo "\n No file to transfer from $replast \n"

fi
#

echo "\n=====>  Um_output.ksh ends: `date` ###########\n"
