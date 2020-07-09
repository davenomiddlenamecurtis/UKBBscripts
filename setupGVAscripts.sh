#!/bin/bash
# DC script to set up GVA analyses, one script per gene

# geneList=/home/rejudcu/reference/allGenes140817.onePCDHG.txt
geneList=/home/rejudcu/reference38/allGenes.20191018.onePCDHG.txt
# geneList=/home/rejudcu/reference/DRDgenes.txt
# disease=MPexomes
# model=bp1.myWeights

# disease=ADSP2
# model=common.withAPOE

disease=UKBB
model=HL.all

refdir=reference38

if [ -z $geneList ]
then
# geneList=/home/rejudcu/SSSDNMclinical/notNeuroGenes.lst
 geneList=/home/rejudcu/SSSDNMclinical/dominantGenes.lst
# geneList=/home/rejudcu/SSSDNMclinical/recessiveGenes.lst
fi
# geneList=/home/rejudcu/reference/DRDgenes.txt
# geneList=/home/rejudcu/tmp/FAM21EP.lst

# disease="UCLEx.Prionb2"
# model="ExAC.ct08.rare"
# model="ct08.cleaned"
# must be in this order or else qdel will delete all the ct08 jobs
if [ -z "$disease" ]
then
  disease=ADSP
fi
if [ -z "$model" ]
then
   model=all
#   model="codeVars.Dam codeVars.Dis"
#   model="codeVars.Dam.NotNeuro codeVars.Dis.NotNeuro"
#  model="codeRecDam codeRecDis"
fi

homeFolder=/cluster/project9/bipolargenomes
argFolder=/home/rejudcu/pars
softwareFolder=/home/rejudcu/bin
dataHome=/home/rejudcu

if [ -z "$disease" -o -z "$model" ]
then
	echo Error in $0: must set environment variables disease and model
	exit
fi

someGenesLeft=no

for d in $disease
do
for m in $model
do

testName=$d.$m
argFile=$argFolder/gva.$testName.arg


# workFolder=/cluster/project8/bipolargenomes/GVA

workFolder=$homeFolder/$d/$testName
mkdir $homeFolder/$d
mkdir $workFolder

nSplits=100

splitScript=$workFolder/scripts/split${nSplits}s.sh
scriptName=$testName.runSplit${nSplits}.sh
mainSplitScript=$workFolder/scripts/$scriptName

qdel $testName.'runSplit*'

nhours=4
vmem=6 
memory=2
queue=queue6
scratch=0

# UKBB analyses were running out of memory with vmem=6
vmem=8

if [ ! -e $workFolder ]; then mkdir $workFolder; fi;
wastebin=$workFolder/wastebin
if [ ! -e $wastebin ]; then mkdir $wastebin; fi
if [ ! -e $workFolder/results ]; then mkdir $workFolder/results; fi;
if [ -e $workFolder/error ]; then mv $workFolder/error $wastebin/error; ( rm -r $wastebin/error & ) ; fi;
mkdir $workFolder/error
if [ -e $workFolder/scripts ]; then mv $workFolder/scripts $wastebin/scripts; (rm -r $wastebin/scripts & ); fi;
mkdir $workFolder/scripts; 
if [ -e $workFolder/temp ]; then mv $workFolder/temp $wastebin/temp; (rm -r $wastebin/temp & ); fi;
mkdir $workFolder/temp; 

cat $geneList | while read geneName
    do
    outFile=$workFolder/results/$testName.$geneName.sao
    if [ ! -e $outFile ]
    then 
		shellScript=$workFolder/scripts/runGVA.$testName.$geneName.sh
		scoreFile=$workFolder/results/$testName.$geneName.sco
		elogFile=$workFolder/results/$testName.$geneName.elog
# I may add an exclusion log file so I can find which variants failed which conditions
		echo "PATH=$softwareFolder:\$PATH 
		rm gva.$geneName.*
		pwd
		commLine=\"geneVarAssoc --arg-file $argFile --gene $geneName \" 
		echo Running:
		echo \$commLine
		\$commLine 
		echo finished running geneVarAssoc
		cp gva*.$geneName.*sco $scoreFile 
		cp gva*.$geneName.*sao $outFile 
		cp gva*.$geneName.elog $elogFile
		if [ ! -s $outFile ] ; then rm -f $outFile $scoreFile $elogFile; fi
		" >> $shellScript
    fi
    done

# was \$commLine > gva.$testName.$geneName.elog 
		
nScriptsWritten=`find $workFolder/scripts -name 'runGVA.*.sh' | wc -l`
if [ $nScriptsWritten -lt $nSplits ]
then 
	nSplits=$nScriptsWritten
fi 

if [ -e  $mainSplitScript ] ; then rm  $mainSplitScript; fi

echo "
#!/bin/bash
#$ -S /bin/bash
#$ -e $workFolder/error
#$ -o $workFolder/error
#$ -l tscr=${scratch}G
#$ -l tmem=${vmem}G,h_vmem=${vmem}G
#$ -l h_rt=${nhours}:0:0
#$ -t 1-$nSplits
#$ -V
#$ -R y

# I used to have #$ -cwd but I am going to try just omitting it as sometimes cannot cd to it
# If that does not work may try -wd /scratch0

date
echo bash $splitScript \$SGE_TASK_ID
bash -x $splitScript \$SGE_TASK_ID
date
" > $mainSplitScript

echo "
#!/bin/bash
set +e
#  was exiting after running just one, possibly because no proper exit code from script
# this should switch off errexit
echo Running \$0 with argument \$1
$workFolder/temp
cd $workFolder/temp
myDir=\$RANDOM
mkdir \$myDir
cd \$myDir # this is all so I can have local vcf and reference folders so par files will work with this and with scratch0
mkdir vcf
mkdir vcf/$disease
cd vcf/$disease
ln -s $dataHome/vcf/$disease/* .
cd ../..
mkdir $refdir
cd $refdir
ln -s $dataHome/$refdir/* .
cd ..
mkdir temp
cd temp # so relative paths will work OK
n=1
find $workFolder/scripts -name 'runGVA*sh' | while read f
do
if [ .\$n == .\$1 ]
then
	echo running source \$f # try using source $f instead of bash $f
	source \$f
	echo finished running source \$f
	rm *
fi
if [ \$n -eq $nSplits ]
then
	n=1
else
	n=\$(( \$n + 1 ))
fi
done
cd ../..
rm -r \$myDir
" > $splitScript

count=`find $workFolder/scripts -name 'runGVA*sh' | wc -l`

if [ $count -gt 0 ]
then
	echo wrote $count scripts
	echo qsub -N $scriptName $mainSplitScript
	pushd $workFolder
# reason for this is that I would get Eqw with qstat -j error message: error: can't chdir to /home/rejudcu/tmp: No such file or directory 
	qsub -N $scriptName $mainSplitScript
	popd
	someGenesLeft=yes
else
	echo No genes left to do for $testName	
fi

done
done

logFile=${0##*/}
if [ $someGenesLeft = yes ]
then
	echo will schedule script to run again
	echo "export disease=\"$disease\"; export model=\"$model\"; export geneList=$geneList; bash $0 &> $workFolder/$logFile.log" | at now + $nhours hours
else
	echo date > $workFolder/$logFile.log
	echo All results files written OK >> $workFolder/$logFile.log
fi
