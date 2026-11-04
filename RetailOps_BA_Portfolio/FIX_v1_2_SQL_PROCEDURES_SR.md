# SQL Server hotfix — v1.2

## What happened
Running `database/02_procedures.sql` in SSMS raised SQL Server error 102 near `RetailOps.Order.` in `dbo.usp_CreateOrder` because the `@Resource` argument of `sys.sp_getapplock` was supplied as a `CONCAT(...)` expression rather than a precomputed variable. That was a bug in the distributed project, not a problem with your SQL Server installation.

## Fix
The revised `02_procedures.sql` now declares `@AppLockResource NVARCHAR(255)`, assigns the concatenated resource key before the `EXEC`, and passes `@Resource=@AppLockResource`.

At the end it checks whether all seven procedures exist, and prints `PASS: All seven operational stored procedures are present.` only if they do.

## Windows instructions
1. Download the **standalone** corrected `02_procedures.sql` or extract the new v1.2 ZIP.
2. If working with the standalone file, replace the old file in `Documents\\RetailOps_BA_Portfolio\\database\\02_procedures.sql`. Close the old query tab in SSMS and reopen the corrected file so you do not run a cached old version.
3. In SSMS, ensure you are connected to ` .\\SQLEXPRESS ` (the script also includes `USE RetailOpsDB;`). Execute the whole corrected script with **F5**.
4. Open the **Messages** tab, not only the SSMS error counter/IntelliSense panel. Look for the exact `PASS` text, and **no `Msg ... Level ...` errors**.
5. For an additional read-only check, run:

```sql
USE RetailOpsDB;
SELECT name FROM sys.procedures
WHERE schema_id = SCHEMA_ID(N'dbo') AND name LIKE N'usp_%'
ORDER BY name;
```

Expected seven rows including `usp_CreateOrder`.

**Do not re-execute `00_create_database.sql` or `01_schema.sql`; they were already completed.** Re-executing `02_procedures.sql` is safe for existing procedures because it uses `CREATE OR ALTER`.

Do not run `03_seed_data.sql` until the procedure script executes without SQL Server errors. Take a screenshot of SSMS Messages if another error occurs.

## Verification limits
The project bundle was checked for file structure and the specific SQL source defect; it was **not executed against a live Microsoft SQL Server** in the assistant's environment. Passing the procedure-existence check is not the same as passing integration tests.
