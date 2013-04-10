#!/bin/ksh
#
arguments=$*
. r.entry.dot
#
eval `cclargs_lite $0 \
  -cfg_file      ""             ""          "[user config file                          ]"\
  -lam_init      ""             ""          "[input data directory for LAM in self-nest)]"\
  -lam_bcs       ""             ""          "[input data directory for LAM in self-nest)]"\
  -geophy_m      ""             ""          "[input data directory for LAM in self-nest)]"\
  -barrier       "0"            "0"         "[DO NOT run binary                         ]"\
  -manoutp       "1"            "1"         "[Manage model output                       ]"\
  -theoc         "${theoc:-0}"  "1"         "[theoretical case flag                     ]"\
  -xchgdir       ""             ""          "[exchange directory                        ]"\
  -timing        "0"            "0"         "[report performance timers                 ]"\
  -task_basedir  "RUNMOD"       "RUNMOD"    "[name of task dir                          ]"\
  -no_setup      "0"            "1"         "[do not run setup                          ]"\
  -_status       "ABORT"        "ABORT"     "[return status                             ]"\
  -_endstep      ""             ""          "[last time step performed                  ]"\
  -_npe          "1"            "1"         "[number of subdomains                      ]"\
  ++ $arguments`

echo "\n=====>  Um_runmod.ksh starts: `date` ###########\n"

set ${SETMEX:-+ex}

# Task structure setup
mkdir -p ${task_basedir}
export TASK_BASEDIR=`true_path $task_basedir`
export TASK_INPUT=${TASK_BASEDIR}/input
export TASK_BIN=${TASK_BASEDIR}/bin
export TASK_WORK=${TASK_BASEDIR}/work
export TASK_OUTPUT=${TASK_BASEDIR}/output
export RPN_COMM_DIAG=0

export fn_const=constantes
export fn_ozone=ozone_clim.fst
export fn_irtab=rad_table.fst

# Generate configuration file on-the-fly if not provided
CFGFILE=''
if [ $cfg_file ] ; then
  if [ -s $cfg_file ] ; then
    echo "Using config file: $cfg_file"
    CFGFILE=`true_path $cfg_file`
  fi
else
#===> input
  INIT_SFC_cfg="#"
  INIT_3D_cfg="#"
  BCDS_3D_cfg="#"
  XCHGDIR_cfg="#"
  GEOPHY_cfg="#"
  OUTCFG_cfg="#"
  NMLCPL_cfg="#"
  if [ -d ${TASK_BASEDIR}/../RUNENT/output/INIT_SFC ] ; then
    INIT_SFC_cfg='# INIT_SFC         ::TASK_BASEDIR::/../RUNENT/output/INIT_SFC'
  fi
  if [ -n "${lam_init}" ] ; then
    INIT_3D_cfg="# INIT_3D         ${lam_init}"
  else
    if [ -d ${TASK_BASEDIR}/../RUNENT/output/INIT_3D ] ; then
      INIT_3D_cfg='# INIT_3D          ::TASK_BASEDIR::/../RUNENT/output/INIT_3D'
    fi
  fi
  if [ -n "${lam_bcs}" ] ; then
    BCDS_3D_cfg="# BCDS_3D         ${lam_bcs}"
  else
    if [ -d ${TASK_BASEDIR}/../RUNENT/output/BCDS_3D  ] ; then
      BCDS_3D_cfg='# BCDS_3D          ::TASK_BASEDIR::/../RUNENT/output/BCDS_3D '
    fi
  fi
  if [ -n "${geophy_m}" ] ; then
    GEOPHY_cfg="# LAM_geophy       ${geophy_m}"
  fi
  # Exchange directory requested
  if [ -n "${xchgdir}" ] ; then
    XCHGDIR_cfg="# xchgdir          ${xchgdir}"
  fi
  if [ -s ${TASK_BASEDIR}_upload/input/coupleur_settings.nml -o -e coupleur_settings.nml ] ; then
    NMLCPL_cfg="# coupleur_settings.nml   ::PWD::/coupleur_settings.nml"
  fi
  if [ -s ${TASK_BASEDIR}_upload/input/output_settings -o -s outcfg.out ] ; then
    OUTCFG_cfg="# output_settings   ::PWD::/outcfg.out"
  fi
  CONSTANTES_cfg="# $fn_const ::AFSISIO::/datafiles/constants/thermoconsts"
  if [ -s ${TASK_BASEDIR}_upload/input/$fn_const -o -s $fn_const ] ; then
    CONSTANTES_cfg="# $fn_const ::PWD::/::fn_const::"
  fi
  OZONE_cfg="# $fn_ozone"
  if [ -s ${TASK_BASEDIR}_upload/input/$fn_ozone -o -s $fn_ozone ] ; then
    OZONE_cfg="# $fn_ozone ::PWD::/$fn_ozone"
  fi
  IRTAB_cfg="# $fn_irtab ::AFSISIO::/datafiles/constants/irtab5_std"
  if [ -s ${TASK_BASEDIR}_upload/input/$fn_irtab -o -s $fn_irtab ] ; then
    IRTAB_cfg="# $fn_irtab ::PWD::/$fn_irtab"
  fi
#===> executables
  FETCHNML_cfg='# Um_fetchnml.ksh   '`which Um_fetchnml.ksh`
  CMCLOG_cfg='# Um_cmclog.ksh     '`which Um_cmclog.ksh`
  UM_MOD_cfg='# Um_model.ksh      '`which Um_model.ksh`
  MPIRUN_cfg='# r.mpirun         '`which r.mpirun2`
#
  CFGFILE=$TMPDIR/mod$$.cfg
  cat > $CFGFILE <<EOF
#############################################
# <input>
${INIT_SFC_cfg}
${INIT_3D_cfg}
${BCDS_3D_cfg}
${GEOPHY_cfg}
# model_settings_template    ::PWD::/::MODEL::_settings.nml
${CONSTANTES_cfg}
${OZONE_cfg}
${IRTAB_cfg}
${OUTCFG_cfg}
${NMLCPL_cfg}
# </input>
# <executables>
# ATM_MOD.Abs      ::PWD::/main::MODEL::dm_::BASE_ARCH::_::MODEL_VERSION::.Abs
${FETCHNML_cfg}
${CMCLOG_cfg}
${UM_MOD_cfg}
${MPIRUN_cfg}
# </executables>
# <output>
${XCHGDIR_cfg}
# </output> 
#############################################
EOF
fi

echo "### Content of config file to TASK_SETUP ####"
cat $CFGFILE 2>/dev/null

echo "\n##### DOTING file $CFGFILE #####"
. $CFGFILE
echo "\n#############################################"

# Use performance timers on request
if [ ${timing} -gt 0 ] ; then export TMG_ON=YES; fi
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}

# Set up working directory if running the first time slice
if [ -s ${TASK_WORK}/000-000/restart ] ; then
  echo "Running in RESTART mode"
else
  if [ ${no_setup} = 0 ] ; then
    echo "\n##### EXECUTING TASK_SETUP #####"
    /bin/rm -rf ${TASK_BASEDIR}/.resetenv ${TASK_WORK}/.resetenv
    ${TASK_SETUP:-task_setup-0.7.7.py} -f $CFGFILE --base $TASK_BASEDIR --clean
    if [ $? = 1 ] ; then . Um_aborthere.ksh "PROBLEM with task_setup.py" ; fi
  fi
fi

/bin/rm -f ${TASK_WORK}/theoc
if [ ${theoc} -gt 0 ] ; then
  touch ${TASK_WORK}/theoc
fi

cp ${TASK_INPUT}/model_settings_template ${TASK_WORK}/model_settings.nml

# Run main program wrapper
. r.call.dot ${TASK_BIN}/Um_model.ksh -barrier ${barrier} -manoutp ${manoutp}

# Config file cleanup
/bin/rm -f $TMPDIR/mod$$.cfg

echo "\n=====>  Um_runmod.ksh ends: `date` ###########\n"

# End of task
. r.return.dot

