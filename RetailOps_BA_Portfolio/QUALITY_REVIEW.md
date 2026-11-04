# RetailOps — quality review and release checklist

**Review date:** 2026-11-04 | **Revision:** 1.1 | **Scope:** Static code/document inspection only, **not** execution against SQL Server.

## Changes implemented in this revision

- **Order idempotency is now payload-aware.** Repeating the same external request key with matching customer, address, store, channel and normalized product quantities returns the original order ID. A mismatched replay raises SQL error **51009** rather than silently accepting a different order. Negative test **N03** verifies this behavior (execution still pending).
- Added a read-only `testing/04_post_install_validation.sql` with 7 install/data-integrity checks, explicit error codes and summary counts.
- Added Windows-first SSMS installation and GitHub publication instructions. Optional `tools/run_on_windows.ps1` automates sequential execution **only if `sqlcmd` is installed**.
- Fixed Power BI import instructions to distinguish **four reporting queries** from an **optional country dimension**.
- `.gitignore` no longer silently excludes a genuine `.pbix` report once one has been built and validated; development caches and database files are excluded.
- Added a practical interview walkthrough and release evidence checklist.
- Added a GitHub Actions workflow for static artifact validation only; runtime SQL / report testing remains manual.

## Risks and opportunities — prioritized

| Priority | Issue | Why it matters | Gate / next action |
|---|---|---|---|
| P0 | SQL has not run on the target local server | Compilation, permissions and realistic performance are unknown | Run 00–06 in SSMS; run V01–V07, T01–T08, N01–N03 |
| P0 | No actual concurrency test result | The core BA promise is preventing double reservation | Use isolated two-window test C01 and save actual output |
| P0 | No `.pbix` report | Power BI is a design/build kit, not a finished dashboard | Build 3 pages, refresh, reconcile to SQL, capture screenshots |
| P1 | No measured query optimization | An index list alone doesn't prove improvement | Record STATISTICS IO/TIME and actual execution plans |
| P1 | Order and PO approval APIs are not implemented | The prototype models stored procedure boundaries, not a running end-user app | Keep scope truthful; explain external service integration as future work |
| P1 | Reporting uses one EUR-equivalent pricing convention, not actual FX/VAT | Avoid financial misrepresentation | Explicitly label reporting as synthetic simplified margin, not true earnings |
| P2 | Warehouse capacity not enforced in allocation/receipt | Real capacity planning requires separate controls | Add as future user story and document operational impact |
| P2 | Retry/deadlock guidance and logging are documentation-only | Deadlocks are possible even with correct lock discipline | Provide client retry policy and tests under load in v2 |
| P2 | Dataset has fixed deterministic generation patterns | Observed 'insights' are demonstrative, not market evidence | Clearly label every insight as derived from synthetic data |

## Definition of done before public portfolio launch

- [ ] Executed numbered SQL scripts on Windows SQL Server with no errors.
- [ ] Saved post-install validation output showing PASS V01–V07.
- [ ] Saved integration output PASS T01–T08 and negative output PASS N01–N03.
- [ ] Performed C01 in two sessions on a disposable copy; recorded actual outcome.
- [ ] Built Power BI `.pbix` with 3 pages, successful refresh and 3 captured screenshots.
- [ ] Matched Power BI revenue and line counts to SQL results.
- [ ] Recorded measured, not fabricated, IO/TIME metrics on same dataset.
- [ ] Replaced `NOT RUN` rows in test evidence only after actual tests.
- [ ] Reviewed all GitHub files for secrets, personal info, credentials and unverified success claims.
- [ ] Described the project clearly as independently built fictional simulation with AI drafting support, NOT a real client assignment.

## Status interpretation

- `PREPARED`: code, tests and documentation authored; can be downloaded and inspected.
- `STATIC CHECKED`: checks of files, markup and named objects pass; SQL **not** executed.
- `EXECUTED`: local SSMS query ran without error, with retained log.
- `VERIFIED`: assertions run and exact results documented.
- `PUBLIC READY`: every P0 gate passed and public claims checked against evidence.

**Current status: STATIC CHECKED (not yet EXECUTED).**

## v1.2 hotfix (2026-11-04)
- Fix SQL Server syntax error 102 in `dbo.usp_CreateOrder` caused by using `CONCAT(...)` directly as the `@Resource` argument to `sys.sp_getapplock`.
- Precompute `@AppLockResource NVARCHAR(255)` and pass the variable to the procedure.
- Replace the unconditional procedure-creation message with a seven-procedure existence check.
- Still awaiting runtime verification in SQL Server; see `FIX_v1_2_SQL_PROCEDURES_SR.md`.

## v1.6 integration-test correction
- Replaced invalid `@ItemsJson=CONCAT(...)` stored procedure arguments in integration and negative test suites.
- Materialized the T07 fulfillment aggregate into an indexed temporary table.
- SQL Server execution pending.
