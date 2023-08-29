#SQL server DSN needs to be set up.
# 1. Open ODBC Data Sources (64-bit) in windows search bar
# 2. Add a User DSN >> Assign a DSN Name >> Connect to the server
# 3. Setup login ID and pw for SQL SERVER authentication >> 
#   Change the default database to the preferred db >> READONLY access.
#   The DSN name, login ID, and pw will be used later.
#   con <- dbConnect("DSN-NAME", uid="LoginID",pwd="Password")
# 4. Install Rtools and RODBC packages
#   install.packages("Rtools")
#   install.packages("readxl")
#   install.packages("dplyr")
#   install.packages("DBI")
#   install.packages("odbc")
#############################################################################################
# Step 0: Define all variables and read data #
#############################################################################################
library(readxl)
library(dplyr)
library(DBI)
library(odbc)

# Cancer types: Bladder, Breast, Colorectal, Esophageal, Gastric, Head and Neck, Liver and Bild Duct, Lung, Ovarian, Pancreas
# Db names
# SEER_bladdercancer
# SEER_breastcancer
# SEER_colorectalcancer
# SEER_esophaguscancer
# SEER_headneckcancer
# SEER_liveribdcancer
# SEER_lungcancer
# SEER_ovarycancer
# SEER_pancreascancer
# SEER_stomachcancer

CancerType <- "Gastric"
SEERCancer_Db_Name <- "SEER_stomachcancer"

# set path  (Example: C:\Development\ES MCED and Clinical Pathway)
base.path <- file.path("C:", "Development", "ES MCED and Clinical Pathway")
CodingTable.file.name <- "Coding Tables.xlsx"

# SQL connection
DSN <- "DSN-NAME"
uid <- "LoginID"
pwd <- "Password"
SQL_ICD_O_3_CodeTable_name <- "ICD_O_3_Code"

# Establish connection in R studio
con <- DBI::dbConnect(odbc::odbc(), DSN, uid=uid,pwd=pwd)


#############################################################################################
# Step 1: Update cancer-specific codes in SQL with the most recent excel file #
#############################################################################################

df.CodingTable <- data.frame(read_excel(file.path(base.path, CodingTable.file.name), sheet = CancerType, col_names = TRUE))
df.ICD_O_3_Code <- subset(df.CodingTable, Code.Type == "ICD-O-3", c(Code, Description))
df.ICD_O_3_Code$Cancer_Type <- CancerType
dbExecute(con, paste0("TRUNCATE TABLE ",SQL_ICD_O_3_CodeTable_name))
dbWriteTable(con, SQL_ICD_O_3_CodeTable_name, df.ICD_O_3_Code, overwrite=TRUE)

# Subset other codes
df.ICD_9_Code <- subset(df.CodingTable,Code.Type == "ICD-9", c(Code, Description)) 
df.ICD_10_Code <- subset(df.CodingTable,Code.Type == "ICD-10", c(Code, Description)) 
df.HCPCS <- subset(df.CodingTable,Code.Type == "HCPCS", c(Code, Description)) 
df.CPT <- subset(df.CodingTable,Code.Type == "CPT", c(Code, Description)) 


#############################################################################################
# Step 2: Get updated cancer-specific patient_id and CancerType to SEER_PatientCohort table #
#############################################################################################
# Refresh data which takes about 3-5 min/cancer
SQL_AttritionRemove_Code <- paste0("DELETE FROM SEER.dbo.SEER_Attrition WHERE CancerType = '", CancerType,"';", collapse="")
dbExecute(con, SQL_AttritionRemove_Code)

SQL_CohortRemove_Code <- paste0("DELETE FROM SEER.dbo.SEER_PatientCohort WHERE CancerType = '", CancerType,"';", collapse="")
dbExecute(con, SQL_CohortRemove_Code)

SQL_CohortUpdate_Code <- paste0("EXEC SEERAttrition @nCancerTableName = 'SEER.dbo.", SEERCancer_Db_Name, "', @nCancerType = '", CancerType,"';", collapse="")
dbExecute(con, SQL_CohortUpdate_Code)

#############################################################################################
# Step 3: SQL query to grab all columns needed #
#############################################################################################

SQL_Patient_Demographic_Code <- paste0("
SELECT DISTINCT(PC.PatientId), 
  C.sex,
  CAST(C.Year_of_diagnosis AS INT) - CAST(C.Year_of_birth AS INT) AS age_at_dx,

FROM SEER.dbo.SEER_PatientCohort PC
LEFT JOIN SEER.dbo.", SEERCancer_Db_Name, " C 
  ON PC.PatientId = C.patient_id
WHERE CancerType = '", CancerType, "'
  AND (C.Sequence_number = 0 OR C.Sequence_number = 1);")
  
Patient_Demographic <- dbGetQuery(con, SQL_Patient_Demographic_Code)




#############################################################################################
# Step 4: Begin with analysis #
#############################################################################################


dbDisconnect(con)
