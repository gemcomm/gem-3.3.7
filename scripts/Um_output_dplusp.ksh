#!/bin/ksh
#
#====> Obtaining the arguments:
eval `cclargs_lite -D  $0 \
     -dm      ""        ""    "[list of dm files]"\
     -dp      ""        ""    "[list of dp files]"\
     -dh      ""        ""    "[list of dh files]"\
     -pm      ""        ""    "[list of pm files]"\
     -pp      ""        ""    "[list of pp files]"\
     -ph      ""        ""    "[list of ph files]"\
  ++ $*`
#
EDIT=editfst+
#
for i in ${dm} ; do
  for src in `ls *dm[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*${i} 2> /dev/null` ; do
    dest=`echo ${src} | sed 's/\(.*\)dm\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(.*\)/\1m\2\3/'`
    /bin/mv $src $dest 2> /dev/null
  done
done
for i in ${pm} ; do
  for src in `ls *pm[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*${i} 2> /dev/null` ; do
    dest=`echo ${src} | sed 's/\(.*\)pm\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(.*\)/\1m\2\3/'`
    echo $EDIT -s ${src} -d ${dest} -i /dev/null
    $EDIT -s ${src} -d ${dest} -i /dev/null
    /bin/rm -f ${src}
  done
done
for i in ${pp} ; do
  for src in `ls *pp[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*${i} 2> /dev/null` ; do
    dest=`echo ${src} | sed 's/\(.*\)pp\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(.*\)/\1p\2\3/'`
    echo $EDIT -s ${src} -d ${dest} -i /dev/null
    $EDIT -s ${src} -d ${dest} -i /dev/null
    /bin/rm -f ${src}
  done
done
for i in ${ph} ; do
  for src in `ls *ph[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*${i} 2> /dev/null` ; do
    dest=`echo ${src} | sed 's/\(.*\)ph\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(.*\)/\1h\2\3/'`
    echo $EDIT -s ${src} -d ${dest} -i /dev/null
    $EDIT -s ${src} -d ${dest} -i /dev/null
    /bin/rm -f ${src}
  done
done
#


