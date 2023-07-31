#Install Rtools and RODBC packages
install.packages("Rtools")
install.packages("RODBC")

#A SQL server DSN needs to be set up.
# 1. Open ODBC Data Sources (64-bit) in windows search bar
# 2. Add a User DSN >> Assign a DSN Name >> Connect to the server
# 3. Setup login ID and pw for SQL SERVER authentication >> Change the default database to the preferred db >> READONLY access
# 4. Finish and test data source

#Establish connection in R studio
con <- odbcConnect("DSN-NAME", uid="LoginID",pwd="Password")
query1 <- sqlQuery(con, "SELECT TOP (1000) [Col1],[Col2] FROM [Database].[dbo].[Table_1]")

#Check results
summary(query1)
