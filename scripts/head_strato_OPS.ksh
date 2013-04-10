#!/usr/bin/ksh -ex
#
cd RUNENT_upload/input

mv ANALYSIS ANALYSIS_orig

cat > e1.dir <<EOF
 desire (-1,"TS")
 zap (-1,"I7",-1,-1,1199,-1,-1)
end
EOF
cat > e2.dir <<EOF
 desire (-1,"TS")
 zap (-1,"I9",-1,-1,1199,-1,-1)
end
EOF

cat > e3.dir <<EOF
 desire (-1,"SD")
 zap (-1,-1,-1,-1,1199,-1,-1)
 stdcopi(-1)
 desire (-1,"SD")
 zap (-1,-1,-1,-1,1198,-1,-1)
 stdcopi(-1)
 desire (-1,"SD")
 zap (-1,-1,-1,-1,1197,-1,-1)
 stdcopi(-1)
 desire (-1,"SD")
 zap (-1,-1,-1,-1,1196,-1,-1)
 stdcopi(-1)
 desire (-1,"SD")
 zap (-1,-1,-1,-1,1195,-1,-1)
 stdcopi(-1)
end
EOF
cp ANALYSIS_orig analysis ; chmod u+w analysis

editfst -s analysis -d analysis_i7 -i e1.dir
editfst -s analysis -d analysis_i9 -i e2.dir
editfst -s analysis -d analysis_sd -i e3.dir
editfst -s analysis_i7 analysis_i9 analysis_sd -d analysis -i /dev/null

mv analysis ANALYSIS

/bin/rm -f e1.dir e2.dir e3.dir analysis_sd analysis_i7 analysis_i9


