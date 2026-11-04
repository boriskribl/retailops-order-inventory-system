/* RetailOps | 00 | SQL Server 2019+ / SQL Server 2025 Express
   Execute on a local SQL Server instance with CREATE DATABASE permissions.
   This script is repeatable and never drops an existing database. */
IF DB_ID(N'RetailOpsDB') IS NULL
    CREATE DATABASE RetailOpsDB;
GO
USE RetailOpsDB;
GO
SET NOCOUNT ON;
SELECT DB_NAME() AS CurrentDatabase, @@VERSION AS SQLServerVersion;
GO
