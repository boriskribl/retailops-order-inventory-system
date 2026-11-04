# C01: Two concurrent allocations — safe, repeatable manual test

This test demonstrates transaction isolation/stock contention without directly editing inventory. It creates two **real test orders in the demo database**, each requesting all units of the same currently available SKU, and later cancels both. Run on **RetailOpsDB demo data only**, never live operational data.

## Runbook

1. Open `testing/concurrency/01_setup.sql` in SSMS; execute once. Copy the **OrderA** and **OrderB** IDs from its result table. Do not re-execute after success.
2. Open `02_session_A.sql` in **SSMS query window A**, and `03_session_B.sql` in **a separate New Query window B**. Substitute each `DECLARE @Order... = 0` placeholder with its corresponding ID. Use two separate windows/connections.
3. Execute **A first**. After you see its lock-holding message, execute **B before A's 30-second delay ends**. B is expected to block until A commits, then report SQL error **51102** as an *expected, caught failure*. The error means insufficient free stock; a successful concurrency test has one allocation, not two.
4. After BOTH windows finish, open `04_verify_and_cleanup.sql`, enter both order IDs, execute. Before cancellation, expected order states are `RESERVED` and `NEW`; afterwards both should be `CANCELLED` and have no active reservations.
5. Capture **Messages** and result grids for test evidence. In `testing/test_execution_log.csv`, record PASS only for observed output. If B reports **INCONCLUSIVE**, it did not overlap with A sufficiently to prove blocking.

## Important details

- Session A intentionally holds locks with `WAITFOR DELAY '00:00:30'` **inside a transaction**. Session B tests whether inventory is serially allocated after that transaction commits.
- This exercises a **last-available-stock scenario**, potentially across several warehouses, without changing inventory quantities manually.
- If the session A allocation fails unexpectedly, do not proceed with B. If any query reports unexpected errors, run the verification/cleanup script **only after ensuring both connections have finished**.
- No current test result is claimed until you execute these scripts against your SQL Server and report the result. `PASS` for data invariants alone does not prove simultaneous execution; look for B's elapsed time.
