# RetailOps v1.6 — test correction

## Why the earlier tests failed
- `@ItemsJson=CONCAT(...)` inside `EXEC dbo.usp_CreateOrder` is not valid T-SQL stored procedure invocation syntax. The JSON must be constructed first in an `NVARCHAR(MAX)` variable and the variable passed to the procedure.
- T07 used a derived aggregate that was still slow on the local dataset. It now first stores totals in a `#FulfillmentTotals` temporary table and adds a clustered index before comparison. The independently executed equivalent produced `MismatchCount = 0` on the user’s server; this version still requires a run.
- The same `EXEC` issue was corrected in `testing/02_negative_tests.sql` for future negative testing.

## On your SQL Server
1. Do **not** rerun 00–06, seed data, or post-install validation.
2. In SSMS open the updated `testing/01_integration_tests.sql` and select `RetailOpsDB`.
3. Press F5 once; check Messages for `PASS T01` ... `PASS T08` **and no SQL errors**.
4. If a test reports an error, stop and capture the complete Messages pane. Tests using transactions should roll back their changes; do not claim they passed unless verified.

## Status
Source inspected and statically checked; not executed against your local SQL Server. The previous run conclusively passed T03, T04, T05, T06; T01 and T02 had syntax errors; T07 was canceled; T08 did not run.
