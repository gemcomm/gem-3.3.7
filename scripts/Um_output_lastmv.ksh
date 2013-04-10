#!/bin/ksh
#
echo "\n=====>  Um_output_lastmv.ksh starts: `date` ###########\n"

DIR_dst=$1
last=$2

cd ${DIR_dst}/$last

if [ $? -eq 0 ] ; then

  Um_checkfs.ksh `pwd`
  if [ $? -ne 0 ] ; then exit 1 ; fi

  for i in * ; do
    if [ -d $i ] ; then
      mkdir -p ${DIR_dst}/$i
      echo "DIR $i mv $i/* ${DIR_dst}/$i"
      mv $i/* ${DIR_dst}/$i
    else
      echo "FILE $i mv $i ${DIR_dst}"
      mv $i ${DIR_dst}
    fi
  done

  cd ${DIR_dst}

  /bin/rm -rf $last

fi
#
echo "\nUm_output_lastmv.ksh ends: "`date`"\n"
