# RetailOps v1.8 — N01 / N03 rerun

N02 (over-receipt) was confirmed PASS on 2026-11-04. N01/N03 did not run because an older local script passed JSON expressions directly into `EXEC`. Use the new standalone file `RetailOps_N01_N03_only_v1_8.sql` (or the revised complete `testing/02_negative_tests.sql` if running on a new copy). The standalone file executes ONLY N01 and N03.

## Procedure
1. Do NOT rerun `03_seed_data.sql`, `06_demo_workflows.sql`, or N02.
2. Open `RetailOps_N01_N03_only_v1_8.sql` in SSMS, verify database RetailOpsDB, press F5.
3. Confirm `PASS N01 insufficient stock rolls back cleanly` and `PASS N03 idempotency payload conflict rejected` without SQL errors.
4. Any failure: stop and send full Messages, no repeats until reviewed.

This is a static fix, not yet executed on the user's SQL Server. The test adds and cancels temporary testing orders if it passes.
