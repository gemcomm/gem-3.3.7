#!/bin/ksh
#
. r.entry.dot

echo "************** Um_upload *******************"

#====> Obtaining the arguments:
eval `cclargs_lite $0 \
  -restart "0"        "0"    "[Restart mode        ]" \
  -_npex   "0"        "0"    "[# of cpus along x   ]" \
  -_npey   "0"        "0"    "[# of cpus along y   ]" \
  -_npeOMP "0"        "0"    "[# of cpus for OpenMP]" \
  -_cpus   "0"        "0"    "[Total # of cpus     ]" \
  -_status "ABORT"    ""     "[return status       ]" \
  ++ $*`

set -e

cfgfile=$ledotfile
. $cfgfile

if [ -z "$BACKEND_mach" -o -z "$EXECDIR" ] ; then
  . Um_aborthere.ksh "Undefined variable (BACKEND_mach or EXECDIR)"
fi

if [ -z "${UM_EXEC_ozone}" ] ; then
  . Um_aborthere.ksh "Undefined variable (UM_EXEC_ozone)"
fi

TARGET_BASE_ARCH=`r.get_arch $BACKEND_mach`
ici=${PWD}

#
#====> Launching message
#
echo "\n#############################################################"
echo             " LAUNCHING ${MODEL} MODEL v_${MODEL_VERSION} on $BACKEND_mach:$EXECDIR type=$TARGET_BASE_ARCH"
echo "############################################################# \n"

TARGET_DIR_E=${EXECDIR}/RUNENT_upload
TARGET_DIR_M=${EXECDIR}/RUNMOD_upload
TARGET_DIR_X=${EXECDIR}/XFERMOD_upload
ssh ${BACKEND_mach} "/bin/rm -rf ${TARGET_DIR_E}/* ${TARGET_DIR_M}/* ${TARGET_DIR_X}/*           ;\
                     mkdir   -p  ${TARGET_DIR_E}/bin ${TARGET_DIR_M}/bin ${TARGET_DIR_X}/bin      \
                                 ${TARGET_DIR_E}/input ${TARGET_DIR_M}/input ${TARGET_DIR_X}/input"

MODELVERSION=$UM_EXEC_binops
if [ -z "$MODELVERSION" ] ; then
  MODELVERSION=${MODEL_VERSION}
fi

main_ntr=main${MODEL}ntr_${TARGET_BASE_ARCH}_${MODELVERSION}.Abs
main_dm=main${MODEL}dm_${TARGET_BASE_ARCH}_${MODELVERSION}.Abs

if [ ${UM_EXEC_ovbin} ] ; then
  cnt=`echo ${UM_EXEC_ovbin} | grep @@ | wc -l`
  if [ $cnt -eq 1 ] ; then
    opt=${UM_EXEC_ovbin##*@@}
    main_ntr=${main_ntr}@@${opt}
    main_dm=${main_dm}@@${opt}
    UM_EXEC_ovbin=${UM_EXEC_ovbin%%@@*}
  fi
  echo "\n Copying ${UM_EXEC_ovbin}/*${TARGET_BASE_ARCH}*.Abs"
  Um_upload_data.ksh -src ${UM_EXEC_ovbin}/${main_ntr} -dst ${BACKEND_mach}:${TARGET_DIR_E}/bin/ATM_NTR.Abs
  Um_upload_data.ksh -src ${UM_EXEC_ovbin}/${main_dm}  -dst ${BACKEND_mach}:${TARGET_DIR_M}/bin/ATM_MOD.Abs 
else
  echo "\n UM_EXEC_ovbin NOT defined -- ABORT --\n"
  exit
fi

for i in `ls -1 ${REPCFG}/*.ksh 2> /dev/null` ; do
  Um_upload_data.ksh -src ${TRUE_HOST}:$i -dst ${BACKEND_mach}:${TARGET_DIR_E}/bin -fcp
  Um_upload_data.ksh -src ${TRUE_HOST}:$i -dst ${BACKEND_mach}:${TARGET_DIR_M}/bin -fcp
  Um_upload_data.ksh -src ${TRUE_HOST}:$i -dst ${BACKEND_mach}:${TARGET_DIR_X}/bin -fcp
done

if [ ${UM_EXEC_ovdata} ] ; then
  echo "\n Copying ${UM_EXEC_ovdata}"
  cd ${UM_EXEC_ovdata}
  scp -q constantes ozoclim* irtab5_* ${BACKEND_mach}:${EXECDIR}/data
  cd $ici
fi

if [ ${UM_EXEC_headscript} ] ; then
  echo "\n Copying ${UM_EXEC_headscript}"
  Um_upload_data.ksh -src ${UM_EXEC_headscript} -dst ${BACKEND_mach}:${TARGET_DIR_E}/bin/headscript -fcp
fi

if [ -n "${UM_EXEC_tailjob_M}" ] ; then
  echo "\n Copying ${UM_EXEC_tailjob_M}"
  Um_upload_data.ksh -src ${UM_EXEC_tailjob_M} -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/tailjob_M -fcp
fi

if [ -n "${UM_EXEC_tailjob_X}" ] ; then
  echo "\n Copying ${UM_EXEC_tailjob_X}"
  Um_upload_data.ksh -src ${UM_EXEC_tailjob_X} -dst ${BACKEND_mach}:${TARGET_DIR_X}/input/tailjob_X -fcp
fi

if [ -n "$UM_EXEC_lam_init" -a "$UM_EXEC_lam_init" == "$UM_EXEC_lam_bcs" ] ; then
  UM_EXEC_lam_bcs=${BACKEND_mach}:${TARGET_DIR_M}/input/INIT_3D
fi

Um_upload_data.ksh -src ${UM_EXEC_anal}       -dst ${BACKEND_mach}:${TARGET_DIR_E}/input/ANALYSIS
Um_upload_data.ksh -src ${UM_EXEC_inrep}      -dst ${BACKEND_mach}:${TARGET_DIR_E}/input/INREP   
Um_upload_data.ksh -src ${UM_EXEC_climato}    -dst ${BACKEND_mach}:${TARGET_DIR_E}/input/CLIMATO 
Um_upload_data.ksh -src ${UM_EXEC_geophy}     -dst ${BACKEND_mach}:${TARGET_DIR_E}/input/GEOPHY  
Um_upload_data.ksh -src ${UM_EXEC_constantes} -dst ${BACKEND_mach}:${TARGET_DIR_E}/input/constantes

Um_upload_data.ksh -src ${UM_EXEC_lam_init}   -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/INIT_3D
Um_upload_data.ksh -src ${UM_EXEC_lam_bcs}    -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/BCDS_3D
Um_upload_data.ksh -src ${UM_EXEC_geophy_m}   -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/LAM_geophy
Um_upload_data.ksh -src ${UM_EXEC_constantes} -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/constantes
Um_upload_data.ksh -src ${UM_EXEC_ozone}      -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/ozone_clim.fst
Um_upload_data.ksh -src ${UM_EXEC_irtab}      -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/rad_table.fst
Um_upload_data.ksh -src ${UM_EXEC_nmlcpl}     -dst ${BACKEND_mach}:${TARGET_DIR_M}/input/coupleur_settings.nml

if [ ${restart} -eq 0 ]; then
  boot=${TMPDIR}/boot
  echo " " > ${boot}
fi


scp -q $REPCFG/$NMLFILE   ${BACKEND_mach}:${TARGET_DIR_E}/input/model_settings_template
scp -q $REPCFG/$NMLFILE   ${BACKEND_mach}:${TARGET_DIR_M}/input/model_settings_template
scp -q $cfgfile           ${BACKEND_mach}:${TARGET_DIR_E}/configexp.cfg
scp -q $cfgfile           ${BACKEND_mach}:${TARGET_DIR_M}/configexp.cfg
set +e
scp -q $REPCFG/outcfg.out ${BACKEND_mach}:${TARGET_DIR_M}/input/output_settings 2> /dev/null
scp -q ${boot}            ${BACKEND_mach}:${TARGET_DIR_E}                       2> /dev/null
scp -q ${boot}            ${BACKEND_mach}:${TARGET_DIR_M}                       2> /dev/null
/bin/rm -f ${boot}

ssh ${BACKEND_mach} "cd ${TARGET_DIR_E}/bin ; set -x ;for i in \`ls -1\` ; do if [ ! -L \$i ] ; then chmod 755 \$i; fi; done"
ssh ${BACKEND_mach} "cd ${TARGET_DIR_M}/bin ; set -x ;for i in \`ls -1\` ; do if [ ! -L \$i ] ; then chmod 755 \$i; fi; done"
set -e

echo "\n ----- Updated content of ${EXECDIR}/*_upload directories on ${BACKEND_mach} -----"
ssh ${BACKEND_mach} "cd ${TARGET_DIR_E} ; pwd ; ls -l * ;\
                     cd ${TARGET_DIR_M} ; pwd ; ls -l * ;\
                     cd ${TARGET_DIR_X} ; pwd ; ls -l *"
echo " -----------------------------------------------------"

_npex=`Um_fetchnml.ksh npex $REPCFG/$NMLFILE`
_npey=`Um_fetchnml.ksh npey $REPCFG/$NMLFILE`
_npex=${_npex:-1}
_npey=${_npey:-1}
_npeOMP=${BACKEND_OMP:-1}

let _cpus=_npex*_npey

_status=OK

echo "************** Um_upload DONE *******************"
. r.return.dot
