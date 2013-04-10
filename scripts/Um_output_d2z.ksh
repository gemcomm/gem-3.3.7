#!/bin/ksh
#
set +x
#====> Obtaining the arguments:
eval `cclargs_lite $0 \
     -rep      "RUNMOD/output"  ""    "[output directory]"\
     -nbf      "0"       "0"   "[nb of files to re-assemble]"\
     -prefix   ""        ""    "[added prefix to output file names]"\
     -split    "0"       "1"   "[bemol is asked to produce coarse and core outputs]"\
  ++ $*`
#
reassembleur=bemol_2007
#
#which ${reassembleur} 1> /dev/null 2>&1 is replaced by r.which
r.which ${reassembleur} 1> /dev/null 2>&1
if [ $? -gt 0 ] ; then
  echo "\n ${reassembleur} not available on `hostname` --- ABORT ---\n"
  exit 1
fi
#
cd ${rep}
if [ $? -gt 0 ] ; then
  exit 2
fi
rep_dir=`pwd`
#
#
laliste=`find ./ -name "*-??-??*" | xargs`
dliste=""
for i in ${laliste} ; do
  step=${i#*_}
  dejala=`echo $dliste | grep $step | wc -l`
  if [ $dejala -lt 1 ] ; then
    dliste="${dliste} $step"
  fi
done
laliste="dm dp dh pm pp ph"
if [ ${split} -eq 0 ] ; then 
  mkdir out_bemol 
else
  mkdir high coarse
fi
for i in ${dliste} ; do
  for n in $laliste ; do
    bliste=`find ./ -name "${prefix}${n}*${i}" | xargs`
    ienati=`echo ${bliste} | wc -w`
    if [ ${ienati} -gt 0 ] ; then
      for ii in ${bliste} ; do
        destination=${ii%%-*}_${ii#*_}
        break
      done
      nn=0
      if [ ${nbf} -gt 0 ] ; then
        nn=`echo ${bliste} | wc -w`
        if [ ${nn} -ne ${nbf} -a ${nn} -ne 0 ] ; then
          echo "\n Incomplete set of files for ${destination}\n"
          exit 3
        fi
      fi
      if [ ${nn} -eq ${nbf} ] ; then
        if [ ${split} -gt 0 ]; then
          /bin/rm -f high/${destination} coarse/${destination}
          echo 'reassembleur         : ' ${reassembleur}
          echo 'source               : ' ${bliste}
          echo 'destination (core)   : ' high/${destination}
          echo 'destination (coarse) : ' coarse/${destination}
          ${reassembleur} -src ${bliste} -core ${rep_dir}/high/${destination} \
               -coarse ${rep_dir}/coarse/${destination} || exit 3
          if [ -s high/${destination} -a -s coarse/${destination} ] ; then
            /bin/rm -f ${bliste}
          fi
        else
          echo "D2ZD2ZD2Z $i $n $nbf: START: "`date`
          /bin/rm -f out_bemol/${destination} ${destination}
          echo 'reassembleur         : ' ${reassembleur}
          echo 'source               : ' ${bliste}
          echo 'destination          : ' ${destination}
          time ${reassembleur} -src ${bliste} -dst out_bemol/${destination} 1> /dev/null 2> /dev/null || exit 3
          if [ -s out_bemol/${destination} ] ; then
            /bin/rm -f ${bliste}
          fi
          echo "D2ZD2ZD2Z: END: "`date`
        fi
      fi

    fi
  done
done
#
if [ ${split} -eq 0 ]; then
   cd out_bemol ; find ./ -type f -exec mv {} ../ \;
   cd ../ ; rmdir out_bemol
fi
#
exit 0


