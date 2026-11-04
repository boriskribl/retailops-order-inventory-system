# RetailOps — quality review and release checklist

**Updated:** 2026-11-04 | **Scope:** inspection of repository contents and review of user-reported local SQL Server / Power BI execution evidence. Not an independently reproduced installation or security audit.

## Current status

**LOCAL DEMO TESTED / PORTFOLIO REVIEW PENDING** — Core SQL integration, negative, concurrency and integrity checks were observed or reported as passed on the local demo. A three-page Power BI report and screenshots are present. Independent fresh-machine reproduction and full presentation validation are not asserted.

## Verified/reported evidence

| Area | Outcome / evidence | Limit |
|---|---|---|
| SQL schema and routines | 25 tables, seven stored procedures, five reporting views | Static files + local SSMS evidence |
| Integration test suite | T01–T08 PASS | Local test run, not CI |
| Expected failures | N01–N03 PASS | Local test run, not CI |
| Concurrency test C01 | One allocation committed; competing session rejected with expected SQL error 51102 after 3,317 ms | Two manual SSMS sessions on demo database |
| Post-install integrity | V01–V06 PASS; optimized V07 MismatchCount=0 | Separate execution for V07 |
| Query performance | 479 ms then 439 ms, 1,975 logical reads both runs | Cache effect; **not** proven optimization |
| Power BI | Three-page .pbix and three screenshots in repository; local refresh reported working | Refresh requires local SQL Server configuration |
| Business analyses | SQL analyses run without error in local SSMS | Results are simulated, not external business validation |

See `testing/test_execution_log.csv`, `testing/performance_results_template.csv` and `README.md` for limitations and evidence descriptions.

## Remaining release checks

- [x] Executed core schema and routines locally.
- [x] Captured/recorded T01–T08 and N01–N03 results.
- [x] Executed C01 two-session scenario.
- [x] Recorded V01–V07 checks.
- [x] Created a three-page Power BI file and dashboard screenshots.
- [x] Recorded SQL IO/TIME measurements without claiming optimization.
- [ ] Independently reproduce all installation and test steps on a fresh demo database.
- [ ] Verify all README links and screenshot rendering on the public GitHub page.
- [ ] Perform final review of the full Git history and current files for secrets and personal information.
- [ ] Verify interview deck visually and update future scope or outdated slides if needed.

## Known modeling and deployment limitations

1. Synthetic transactions and uniformly generated margins prevent real market-performance inference.
2. Pricing follows simplified EUR reporting logic; VAT/FX and statutory accounting are not implemented.
3. User interface, production API layer, authentication/RBAC, payments and live external integrations are not implemented.
4. Warehouse capacity, backorders, supplier approvals and full observability remain future work.
5. Multi-user load/deadlock resilience beyond the demonstration C01 scenario is unverified.
6. All claims of success apply only to the local educational test environment, not production readiness.

## Historical fixes retained in source

- Stored procedure app-lock resource is assigned to a variable rather than passed using a direct `CONCAT(...)` expression.
- Order request idempotency rejects conflicting payloads with expected error 51009.
- Test SQL corrected for invalid procedure argument expressions and validation V07 was optimized.
- The sales ordered-value aggregation excludes cancelled orders; the underlying order-line detail can still include their raw ordered value.
