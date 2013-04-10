#!/bin/ksh 
#
arguments=$*
eval `cclargs_lite $0 \
 -src   ""       ""    "[ ]" \
 -dst   ""       ""    "[ ]" \
 -fcp   "0"      "1"   "[ ]" \
 -q     "0"      "1"   "[ ]" \
 ++ $arguments`

set -e 

src_mach=`echo $src | awk '{print $1}'`
src_file=`echo $src | awk '{print $2}'`
dst_mach=`echo $dst | awk '{print $1}'`
dst_file=`echo $dst | awk '{print $2}'`

if [ -z "$src" -o -z "$dst_mach" -o -z "$dst_file" ] ; then
  exit 0
fi

if [ -z "$src_file" ] ; then
  src_file=$src_mach
  src_mach=$dst_mach
fi 

cnt=`echo $src_file | grep @@ | wc -l`
if [ $cnt -eq 1 ] ; then
  opt=${src_file##*@@}
  src_file=${src_file%%@@*}
  fcp=1
fi

if [ ${src_mach} = ${dst_mach} -a $fcp -eq 0 ] ; then
  if [ $q -eq 0 ] ; then
    echo "ln -sf $src_file ${dst_file}/."
  fi
  ssh ${dst_mach} "ln -sf $src_file ${dst_file}"
else
  if [ $fcp -gt 0 ] ; then
    opt=-L
  fi
set +e
  isrep=0
  ssh $src_mach "cd $src_file 2> /dev/null"
  if [ $? -eq 0 ] ; then
    isrep=1
  fi
set -e
  if [ $isrep -eq 1 ] ; then
    rootdir=`dirname  ${dst_file}`
    dirname=`basename ${dst_file}`
    echo "r.rsync -ssh $opt $src_mach:${src_file} ${rootdir};echo STATUS=\$?" | ssh ${dst_mach} bash --login > $TMPDIR/r.rsync.lis
    grep "STATUS=" $TMPDIR/r.rsync.lis > $TMPDIR/r.rsync.err
    . $TMPDIR/r.rsync.err ; /bin/rm -f $TMPDIR/r.rsync.lis $TMPDIR/r.rsync.err
    if [ $STATUS -ne 0 ] ; then exit 1 ; fi
    ssh ${dst_mach} "mv ${rootdir}/`basename ${src_file}` ${rootdir}/$dirname"
  else
    echo "r.rsync -ssh $opt $src_mach:${src_file} ${dst_file};echo STATUS=\$?" | ssh ${dst_mach} bash --login > $TMPDIR/r.rsync.lis
    grep "STATUS=" $TMPDIR/r.rsync.lis > $TMPDIR/r.rsync.err
    . $TMPDIR/r.rsync.err ; /bin/rm -f $TMPDIR/r.rsync.lis $TMPDIR/r.rsync.err
    if [ $STATUS -ne 0 ] ; then exit 1 ; fi
  fi
  exit 0
fi

