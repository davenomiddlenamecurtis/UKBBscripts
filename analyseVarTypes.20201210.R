#!/share/apps/R-3.6.1/bin/Rscript

# script to get data files to analyse contribution of different types of variant to phenotype

varScoreFile="UKBB.HL.varCounts.20201211.LDLR.sco"
PCsFile="/SAN/ugi/UGIbiobank/data/downloaded/ukb23155.common.all.eigenvec"
sexFile="/home/rejudcu/UKBB/UKBB.sex.20201111.txt"
wd="~/UKBB/lipids/HL.20201103/genes"
nVarTypes=12 # 10000000000
types=c(
"IntronicEtc",
"FivePrime",
"Synonymous",
"SpliceRegion",
"ThreePrime",
"ProteinAltering",
"InDel",
"LOF",
"SpliceSite",
"SIFT",
"PossDam",
"ProbDam")

setwd(wd)

varScores=data.frame(read.table(varScoreFile,header=FALSE,sep=""))
PCsTable=data.frame(read.table(PCsFile,header=TRUE,sep="\t"))
sexTable=data.frame(read.table(sexFile,header=TRUE,sep="\t"))

varTypes=data.frame(matrix(ncol=3+nVarTypes,nrow=nrow(varScores)))

colnames(PCsTable)[1:2]=c("FID","IID")
formulaString=("Pheno ~")
for (p in 1:20) {
  formulaString=sprintf("%s PC%d +",formulaString,p)
  colnames(PCsTable)[2+p]=sprintf("PC%d",p)
}

varTypes[,1:3]=varScores
colnames(varTypes)[1:3]=c("IID","Pheno","VarScore")
typeNames=""
for (v in 1:nVarTypes) {
  colnames(varTypes)[3+v]=sprintf(types[v])
  typeNames=sprintf("%s + %s",typeNames,types[v])
  varTypes[,3+v]=varTypes[,3]%%10
  varTypes[,3]=floor(varTypes[,3]/10)
}
formulaString=sprintf("%s Sex %s",formulaString,typeNames)

allData=merge(varTypes,PCsTable,by="IID",all=FALSE)
allData=merge(allData,sexTable,by="IID",all=FALSE)

model=glm(as.formula(formulaString), data = allData, family = "binomial")
summary(model)

coeffs=data.frame(matrix(ncol=5,nrow=nVarTypes))
coeffs[,2:5]=summary(model)$coefficients[23:(23+nVarTypes-1),]
coeffs[,1]=types
coeffs$OR=exp(coeffs[,2])
coeffs$LCL=exp(coeffs[,2]-coeffs[,3])
coeffs$HCL=exp(coeffs[,2]+coeffs[,3])
coeffs$p=coeffs[,5]
coeffs$variant=coeffs[,1]
coeffs$result=sprintf("%.2f (%.2f - %.2f), p=%f",coeffs$OR,coeffs$LCL,coeffs$HCL,coeffs$p)
coeffs



