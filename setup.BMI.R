#!/share/apps/R-3.6.1/bin/Rscript

# script to get data files to analyse association with BMI

# note that the column number to provide is one higher than that given in http://www.davecurtis.net/UKBB/ukb41465.html
targetDir="/home/rejudcu/UKBB/BMI.20210111"
BMICol=4039
setwd(targetDir)
cmd=sprintf("bash /home/rejudcu/UKBB/UKBBscripts/extract.UKBB.var.exomes.20201207.sh BMI %d",BMICol+1)
system(cmd)
