#!/bin/ksh
#
rep2check=${1:-./}
fs_c=FSFS`df $rep2check 2> /dev/null | awk '{print $NF}'`
fs_h=FSFS`df ${HOME}    2> /dev/null | awk '{print $NF}'`

if [ -d $rep2check ] ; then
  if [[ $fs_c = $fs_h ]] ; then
    echo "\n Filesystem can not be $rep2check -- ABORT --\n"
    exit 1
  fi
else
  echo "\n Directory $rep2check is unavailable -- ABORT --\n"
  exit 1
fi
echo "\n Directory $rep2check is OK (not in your \$HOME) \n"
df $rep2check
exit 0
