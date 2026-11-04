# RetailOps v1.4 — V07 validation speed fix

The original `testing/04_post_install_validation.sql` V07 step ran a correlated `OUTER APPLY` with an aggregate for each order line. At 100,000+ orders this was very slow in the user's SQL Server Express environment. The user cancelled the query after successful PASS V01 through PASS V06. Cancellation was not a failed assertion.

v1.4 materializes one grouped `#FulfillmentTotals` temporary table, indexes its `OrderItemID`, and joins that result to the qualifying order items. The check remains **read-only for the actual business tables**; it creates/drops a session-local temp table.

## If V01–V06 already passed

Run `testing/05_validation_v07_fast.sql` in a new SSMS query window. `MismatchCount = 0` and an empty mismatch sample mean V07 passed. Save the actual results or a screenshot for your project evidence; do not mark V07 passed without running it.

## Future clean installation

`testing/04_post_install_validation.sql` now includes the optimized V07 and can be used for a full validation. The change is not a new schema or stored procedure; **do not rerun seed scripts or recreate your database**.

No SQL Server runtime execution was available to the author; verify on your own instance.
