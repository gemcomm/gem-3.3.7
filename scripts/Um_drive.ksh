#!/bin/ksh
#
arguments=$*
if ! [ -n "${MODEL}" -a -n "${MODEL_VERSION}" -a -n "${MODEL_PATH}" ] ; then
  echo "\n Shadow script Um_launch could NOT establish environment"
  echo " Model environment not set properly --- ABORT ---\n" ; exit 1
fi

. r.entry.dot

#====> Obtaining the arguments:
eval `cclargs_lite $0 \
 -liste      "0"         "1"    "[List available OPS configs]" \
 -restart    "0"         "1"    "[Restart mode              ]" \
 -_job       ""          ""     "[OUTPUT: jobname           ]" \
 -_listing   ""          ""     "[OUTPUT: listing directory ]" \
 -_npex      "0"         "0"    "[OUTPUT: # of cpus along x ]" \
 -_npey      "0"         "0"    "[OUTPUT: # of cpus along y ]" \
 -_npeOMP    "0"         "0"    "[OUTPUT: # of OpenMP cpus  ]" \
  ++ $arguments`

# Check validity of input arguments
if [ -z "$1" -o "`echo $1 | cut -c 1`" = "-" ] ; then
  echo "\nUSAGE: Um_launch DIRECTORY [OPTIONS (-help for list)]\n"; exit 1
fi
if [ ! -d $1 ] ; then
  echo "\nERROR: $1 is not a directory\n"; exit 1
fi

if [ $liste -gt 0 ] ; then
  echo "\n LISTE of available OPS configs:"
  find ${MODEL_PATH}/run_configs -name OG*_* -exec basename {} \;
  find ${MODEL_PATH}/run_configs -name OL*_* -exec basename {} \;
  echo
  exit 0
fi

export REPCFG=$1
export NMLFILE=${MODEL}_settings.nml
export ledotfile=${REPCFG}/configexp_drive.cfg

if [ ! -s $ledotfile       ] ; then . Um_aborthere.ksh "File $ledotfile unavailable"       ; fi
if [ ! -s $REPCFG/$NMLFILE ] ; then . Um_aborthere.ksh "File $REPCFG/$NMLFILE unavailable" ; fi

. $ledotfile

if [ ! $BACKEND_mach ] ; then . Um_aborthere.ksh "BACKEND_mach undefined" ; fi
if [ ! $UM_EXEC_exp  ] ; then . Um_aborthere.ksh "UM_EXEC_exp undefined"  ; fi

if [ -n "$BACKEND_execdir" ] ; then
  export EXECDIR=${BACKEND_execdir}
else
  rootdir_exec=${HOME}/MODEL_EXEC_RUN/${BACKEND_mach}
  ssh $BACKEND_mach "cd ${rootdir_exec} 2> /dev/null;echo \$?" > $TMPDIR/flag$$
  flagrootdir=X`cat $TMPDIR/flag$$` ; /bin/rm -f $TMPDIR/flag$$
  if [ "$flagrootdir" != "X0" ] ; then 
    . Um_aborthere.ksh "Directory ${rootdir_exec} unavailable on $BACKEND_mach"
  fi
  export EXECDIR=${rootdir_exec}/${MODEL}/${UM_EXEC_exp}
fi

_listing=${BACKEND_listings:-${HOME}/listings}
if [ -d $_listing/${BACKEND_mach} -o -L $_listing/${BACKEND_mach} ] ; then
  _listing=$_listing/${BACKEND_mach}
fi
export LISTING=$_listing

#
#====> Uploading stuff on ${batch_mach}
#
. r.call.dot Um_upload.ksh -restart $restart
if [ "$_status" != "OK" ] ; then . Um_aborthere.ksh "Problem with Um_upload.ksh" ; fi

PHYSICS_VERSION=`Um_fetchnml.ksh phy_pck_version $REPCFG/$NMLFILE | sed "s/RPN-CMC_//"`

#
#====> Establishing jobnames
#
PPID=$$
#
lajob=${_job:-${UM_EXEC_exp}}
jobname=${REPCFG}/${lajob}
/bin/rm -f ${jobname}_*
xfer_lis=''
if [ ${UM_EXEC_xferl:-0} -gt 0 ] ; then
  xfer_lis="${LISTING}/${lajob}_*.${PPID}*"
fi

batch_class=""
batch_nosubmit=""
if [ ${BACKEND_nosubmit} -gt 0 ] ; then batch_nosubmit="-nosubmit"         ; fi
if [ ${BACKEND_class}          ] ; then batch_class="-cl ${BACKEND_class}" ; fi

if [ ${UM_EXEC_r_ent:-1} -gt 0 ] ; then

  cat > ${jobname}_E << EOF01
set +x
echo "##### UM_TIMING BEGIN -ENTRY-: "\`date\`
echo "\n######################################################"
echo "########### USER'S JOB STARTS HERE - ENTRY ###########"
echo "######################################################\n"
#
. /users/dor/armn/mod/ovbin/sm5 -version ${MODEL_VERSION}
set -x
#

Um_checkfs.ksh $EXECDIR
if [ \$? -ne 0 ] ; then exit 1 ; fi

cd $EXECDIR

. RUNENT_upload/configexp.cfg

if [ -s RUNENT_upload/boot ] ; then
  /bin/rm -rf RUNENT ; /bin/rm -f RUNENT_upload/boot
fi

export TASK_SETUP=$TASK_SETUP
export UM_EXEC_cmclog=${UM_EXEC_cmclog}

headscript=RUNENT_upload/bin/headscript
if [ -x \${headscript} ] ; then 
  echo "\n Running ${UM_EXEC_headscript} as "\${headscript}"\n"
  \${headscript}
fi

RUNENT=RUNENT_upload/bin/Um_runent.ksh
if [ ! -x \${RUNENT} ] ; then
  RUNENT=""
fi

. r.call.dot \${RUNENT:-Um_runent.ksh} -inrep ${UM_EXEC_inrep} -anal ${UM_EXEC_anal} \\
                               -climato ${UM_EXEC_climato} -geophy ${UM_EXEC_geophy}

if [ "\$_status" = "ED" ] ; then
  tailjob=RUNENT_upload/input/tailjob_E
  if [ -s \${tailjob} ] ; then
    echo "\n LAUNCHING "\${tailjob}"\n"
    soumet_lajob \${tailjob} ; /bin/rm -f \${tailjob}
  fi
fi
#
echo "##### UM_TIMING END -ENTRY-: "\`date\`
EOF01
  set -x
  ord_soumet ${jobname}_E -t $BACKEND_time_ntr -cm 1G -cpus 1x1 -mach $BACKEND_mach  \
                      -listing $_listing -jn `basename ${jobname}_E` -ppid $PPID     \
                      -mpi ${batch_class} -nosubmit
  set +x
  if [ $? -eq 0 ] ; then
    mv lajob.tar ${jobname}_E.tar
  else
    echo "\n PROBLEM with ord_soumet ${jobname}_E -- ABORT --\n"
    exit 1
  fi

fi

if [ `r.get_arch $BACKEND_mach` = "AIX-powerpc7" ] ; then
  if [ ${BACKEND_SMT} -gt 0 ] ; then
    SMT=-smt
  fi
fi

if [ ${UM_EXEC_r_mod:-1} -gt 0 ] ; then

  cat > ${jobname}_M << EOF02
set +x
echo "##### UM_TIMING BEGIN -MODEL-: "\`date\`
echo "\n######################################################"
echo "########### USER'S JOB STARTS HERE - MODEL ###########"
echo "######################################################\n"
#
. /users/dor/armn/mod/ovbin/sm5 -version ${MODEL_VERSION}
set -x
#
Um_checkfs.ksh $EXECDIR
if [ \$? -ne 0 ] ; then exit 1 ; fi

cd $EXECDIR

. RUNMOD_upload/configexp.cfg

if [ -s RUNMOD_upload/boot ] ; then
  /bin/rm -rf RUNMOD ; /bin/rm -f RUNMOD_upload/boot
fi

get_info_nodes \$LOADL_STEP_ID

export TASK_SETUP=$TASK_SETUP
export UM_EXEC_cmclog=${UM_EXEC_cmclog}

RUNMOD=RUNMOD_upload/bin/Um_runmod.ksh
if [ ! -x \${RUNMOD} ] ; then
  RUNMOD=""
fi

if [[ \$BASE_ARCH = Linux ]] ; then
  . r.ssmuse.dot mpich2
fi

. r.call.dot \${RUNMOD:-Um_runmod.ksh} -lam_init \${UM_EXEC_lam_init} -lam_bcs \${UM_EXEC_lam_bcs} \\
                                       -geophy_m \${UM_EXEC_geophy_m} -xchgdir \${UM_EXEC_xchgdir} \\
                                       -barrier  \${UM_EXEC_barrier}  -timing  \${UM_EXEC_timing}  \\
                                       -manoutp  \${UM_EXEC_manoutp}

if [ "\$_status" != "ABORT" ] ; then

  XFERSH=RUNMOD_upload/bin/Um_output.ksh
  if [ ! -x \${XFERSH} ] ; then
    XFERSH=""
  fi

  set -x
  \${XFERSH:-Um_output.ksh} -execdir ${EXECDIR} -dotcfg RUNMOD_upload/configexp.cfg \
                            -job ${UM_EXEC_exp}_X -endstepno \$_endstep -ppid $PPID \
                            -phyversion ${PHYSICS_VERSION}                          \
                            -listm ${xfer_lis} -mod_status \$_status -listing $_listing
  
  if [ "\$_status" = "ED" ] ; then
     /bin/rm -rf RUNENT/output
     tailjob=RUNMOD_upload/input/tailjob_M
     if [ -s \${tailjob} ] ; then
       echo "\n LAUNCHING "\${tailjob}"\n"
       soumet_lajob \${tailjob} ; /bin/rm -f \${tailjob}
     fi
   fi
   set +x

else

  Um_aborthere.ksh "Problem with Um_runmod.ksh"

fi
#
SOUMET=ls
if [ "\$_status" = "RS" ] ; then
  SOUMET=qsub
else
  if [ "\$_status" = "ED" ] ; then
    SOUMET=rm
  fi
fi
echo "##### UM_TIMING END -MODEL-: "\`date\`
STEP_ID=\`echo \$LOADL_STEP_ID | sed 's/cmc\.ec\.gc\.ca\.//'\`
llq -l \$STEP_ID

EOF02

  if [ $UM_EXEC_barrier -eq 0 ] ; then
    set -x
    ord_soumet ${jobname}_M \ -mach $BACKEND_mach -t $BACKEND_time_mod -cm $BACKEND_cm \
                              -cpus ${_cpus}x${_npeOMP} -clone -listing $_listing      \
                              -jn `basename ${jobname}_M` -mpi -ppid $PPID ${batch_class} \
                              -nosubmit $SMT
    set +x
    if [ $? -eq 0 ] ; then
      mv lajob.tar ${jobname}_M.tar
    else
      echo "\n PROBLEM with ord_soumet ${jobname}_M -- ABORT --\n"
      exit 1
    fi
  fi

fi

######################################################################

if [ $UM_EXEC_barrier -gt 0 ] ; then BACKEND_nosubmit=1 ; fi

if [ $BACKEND_nosubmit -eq 0 ] ; then
  if [ -s ${jobname}_E.tar ] ; then
    if [ -s ${jobname}_M.tar ] ; then
      scp ${jobname}_M.tar $BACKEND_mach:${EXECDIR}/RUNENT_upload/input/tailjob_E
    fi
    echo "\n Launching: `basename ${jobname}_E` with soumet_lajob\n"
    soumet_lajob ${jobname}_E.tar
  elif [ -s ${jobname}_M.tar ] ; then
    echo "\n Launching: `basename ${jobname}_M` with soumet_lajob\n"
    soumet_lajob ${jobname}_M.tar
  else
    echo "\n =====> NO JOB TO launch"
  fi
else
  echo "\n =====> JOB NOT launched"
fi

echo $USER ${MODEL} 'v_'${MODEL_VERSION} $BACKEND_mach `date` >> /users/dor/armn/mid/public/Um_driver.log 2> /dev/null

echo "\n Config directory: `true_path $REPCFG`\n"

_job=${jobname}
_listing=${LISTING}
#
. r.return.dot
