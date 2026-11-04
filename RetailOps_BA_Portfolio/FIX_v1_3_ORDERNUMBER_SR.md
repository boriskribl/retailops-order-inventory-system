# RetailOps v1.3 — fix for OrderNumber overflow (SQL error 2628)

## Diagnosis
`dbo.SalesOrders.OrderNumber` is `VARCHAR(40)`, but `usp_CreateOrder`
previously inserted `'PENDING-' + UUID` (44 characters). The INSERT failed
inside its transaction, so the demo did not create the new order.

## Change
`database/02_procedures.sql`: use `'P-' + UUID` (38 characters) as a
short, randomly generated, unique placeholder; then replace with
`RO-000000000000` format based on the assigned OrderID as before.

## Recovery on an existing SQL Server Express installation
1. **Do not** rerun `00_create_database.sql`, `01_schema.sql`, or `03_seed_data.sql`.
2. Replace the old `database/02_procedures.sql` with the v1.3 file.
3. Open that file in SSMS, choose `RetailOpsDB`, press **F5**. It uses
   `CREATE OR ALTER PROCEDURE` and preserves existing data.
4. Confirm `PASS: All seven operational stored procedures are present.`
   in the **Messages** tab, with no preceding SQL errors.
5. Run `database/06_demo_workflows.sql` again. The later purchase receipt
   batch may already have executed before the first error; its receipt
   references are guarded against repeat execution.
6. Run `testing/04_post_install_validation.sql` and retain actual PASS
   evidence in your test log.

### Preflight read-only check (optional)
```sql
USE RetailOpsDB;
SELECT COUNT(*) AS DemoOrders
FROM dbo.SalesOrders
WHERE ExternalRequestKey='PORTFOLIO-DEMO-001';
SELECT COUNT(*) AS HistoricalOrders
FROM dbo.SalesOrders WHERE OrderNumber LIKE 'HIST-%';
```
Expected before successful demo: `DemoOrders=0`, `HistoricalOrders=100000`.
If the demo order exists, do not rerun blindly; inspect its status first.

## Validation status
The source change and string lengths were statically checked. Running SQL
on the user's SQL Server (and validating the entire workflow) remains pending.
