#!/bin/ksh

arguments=$*
. r.entry.dot

DIR=$MODEL_PATH/dfiles/${BASE_ARCH}/bcmk
inrep=$DIR
anal=$DIR/20010920.120000
climato=$DIR/clim_gef_400_mars96
geophy=$DIR/geophy_400.fst_0000001-0000001

eval `cclargs_lite -D " " $0 \
  -inrep        "$inrep"    ""        "[input directory ]" \
  -anal         "$anal"     ""        "[analysis        ]" \
  -climato      "$climato"  ""        "[climatology file]" \
  -geophy       "$geophy"   ""        "[genphysX file   ]" \
  -cfg_file     ""          ""        "[user config file]" \
  -task_basedir "RUNENT"    "RUNENT"  "[name of task dir]" \
  -no_setup      "0"        "1"       "[do not run setup]" \
  -_status      "ABORT"     "ABORT"   "[return status   ]" \
  ++ $arguments`

echo "\n=====>  Um_runent.ksh starts: `date` ###########\n"

set ${SETMEX:-+ex}

# Task structure setup
if [ ${no_setup} = 0 ] ; then
  rm -fr ${task_basedir:-yenapas}/*
fi
mkdir -p ${task_basedir}
TASK_BASEDIR=`true_path $task_basedir`
export TASK_BASEDIR
#
export TASK_INPUT=${TASK_BASEDIR}/input
export TASK_BIN=${TASK_BASEDIR}/bin
export TASK_WORK=${TASK_BASEDIR}/work
export TASK_OUTPUT=${TASK_BASEDIR}/output

export fn_const=constantes

# Generate configuration file on-the-fly if not provided
CFGFILE=''
if [ -n "$cfg_file" ] ; then
  if [ -s $cfg_file ] ; then
    echo "Using config file: $cfg_file"
    CFGFILE=`true_path $cfg_file`
  fi
else
#===> input
  ANALYSIS_cfg='#'
  INREP_cfg='#'
  CLIMATO_cfg='#'
  GEOPHY_cfg='#'
  if [ -n "${anal}" ] ; then
    ANALYSIS_cfg="# ANALYSIS         ${anal}"
  fi
  if [ -n "${inrep}" ] ; then
    INREP_cfg="# INREP         ${inrep}"
  fi
  if [ -n "${climato}" ] ; then
    CLIMATO_cfg="# CLIMATO         ${climato}"
  fi
  if [ -n "${geophy}" ] ; then
    GEOPHY_cfg="# GEOPHY         ${geophy}"
  fi
  CONSTANTES_cfg="# $fn_const ::AFSISIO::/datafiles/constants/thermoconsts"
  if [ -s $fn_const ] ; then
    CONSTANTES_cfg="# $fn_const ::PWD::/::fn_const::"
  fi
#===> executables
  FETCHNML_cfg='# Um_fetchnml.ksh   '`which Um_fetchnml.ksh 2> /dev/null`
  CMCLOG_cfg='# Um_cmclog.ksh     '`which Um_cmclog.ksh   2> /dev/null`
  UM_NTR_cfg='# Um_entry.ksh      '`which Um_entry.ksh    2> /dev/null`
#
  CFGFILE=$TMPDIR/ntr$$.cfg
  cat > $CFGFILE <<EOF
#############################################
# <input>
${ANALYSIS_cfg}
${INREP_cfg}
${CLIMATO_cfg}
${GEOPHY_cfg}
# model_settings_template   ::PWD::/::MODEL::_settings.nml
${CONSTANTES_cfg}
# </input>
#
# <executables>
# ATM_NTR.Abs      ::PWD::/main::MODEL::ntr_::BASE_ARCH::_::MODEL_VERSION::.Abs
${FETCHNML_cfg}
${CMCLOG_cfg}
${UM_NTR_cfg}
# </executables>
#
# <configs>
# </configs> 
# <output>
# </output> 
#############################################
EOF
fi

echo "### Content of config file to TASK_SETUP ####"

cat $CFGFILE 2>/dev/null
echo "\n##### DOTING file $CFGFILE #####"
. $CFGFILE
echo "\n#############################################"

# Set up working directory
if [ ${no_setup} = 0 ] ; then
  echo "\n##### EXECUTING TASK_SETUP #####"
  /bin/rm -f ${TASK_BASEDIR}/.resetenv ${TASK_WORK}/.resetenv
  ${TASK_SETUP:-task_setup-0.4.4.py} -f $CFGFILE --base $TASK_BASEDIR --clean
  if [ $? = 1 ] ; then . Um_aborthere.ksh "PROBLEM with task_setup.py" ; fi
fi

cp ${TASK_INPUT}/model_settings_template ${TASK_WORK}/model_settings.nml

# Run main program wrapper
. r.call.dot ${TASK_BIN}/Um_entry.ksh

# Config file cleanup
/bin/rm -f $TMPDIR/ntr$$.cfg

echo "\n=====>  Um_runent.ksh ends: `date` ###########\n"

# End of task
. r.return.dot



