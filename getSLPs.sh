#!/bin/bash
#$ -S /bin/bash
#$ -cwd
#$ -l tmem=1G,h_vmem=1G
#$ -l h_rt=20:0:0
#$ -V
#$ -R y
#$ -e /home/rejudcu/tmp
#$ -o /home/rejudcu/tmp

# model="ct08 ct08.rare"
# model=ExAC.ct08.rare
# model=1000G.ct08.rare
# disease=BP
# disease=WKS
# disease=IBDAJ
# disease="MIGen" # this MUST be the disease because otherwise copyVCF does not work
disease=ADSP2
model=common.withAPOE

disease=UKBB
model=seenPsychDepn.all

# disease="UCLEx.Prionb2"
if [ .$disease == . ]
then
  disease=Ashkenazi_ASJ
fi

if [ -z "$model" -o -z "$disease" ]
then
	echo need to set disease and model
	exit
fi

for d in $disease
do
for n in $model
do 

testName=$d.$n

if [ .$testName == . ]
then
	echo Need to set testName
	exit
fi
# testName=BPrare
 
workFolder=/cluster/project9/bipolargenomes/$d/$testName
# workFolder=/cluster/project9/bipolargenomes/SCHEMA/results/$d/$testName
resultsFolder=$workFolder/results
summFile=$workFolder/$testName.summ.txt

# NB must never have two tabs at start of line because will break you out of quoted segment

getSLPs='
BEGIN { ORS=""; nSLP=0; } 
{
if ($1 == "SLP" || $1 == "tSLP" || $1 == "tMLP" || $1 == "linrSLP" || $1 == "lrSLP") 
	{
	nSLP=nSLP+1;
	SLPs[nSLP]=$3;
	}
}
END {
    if (nSLP > 0) {
	print gene "\t";
	for (i=1; i<=nSLP; ++i) {
	print SLPs[i] "\t";
	}
	print "\n";
	}
}
'

# echo Gene$'\t'SLPD$'\t'SLPR$'\t'SLPHA$'\t'SLPHO > $summFile
# echo Gene$'\t'SLP$'\t'tSLPscore$'\t'tSLPscorePC$'\t'tSLPscorePCPRS$'\t'tSLPscorePCCNV$'\t'tSLPscoreALL> $summFile
echo Gene$'\t'tSLP$'\t'lrSLPwithPCs$'\t'lrSLP> $summFile
# echo Gene$'\t'SLP$'\t'tSLP$'\t'tSLPPC> $summFile

find  $resultsFolder -name '*.sao' | while read resultsFile
	do
	gene=${resultsFile%.sao}
	gene=${gene#*$model.}
	awk -v gene=$gene "$getSLPs" $resultsFile >> $summFile
	done
done
done
