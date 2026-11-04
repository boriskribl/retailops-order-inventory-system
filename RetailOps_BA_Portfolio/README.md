> **v1.4 validation performance fix:** V07 now aggregates fulfillment quantities once instead of performing a correlated aggregate for each order item. If V01–V06 have passed, run `testing/05_validation_v07_fast.sql` and check that `MismatchCount = 0`. See `FIX_v1_4_V07_SPEED_SR.md`.

> **v1.3 SQL runtime fix:** `02_procedures.sql` now uses a 38-character temporary `OrderNumber` instead of a 44-character value that exceeded `VARCHAR(40)`. See `FIX_v1_3_ORDERNUMBER_SR.md`. The entire demo and integration tests still require execution in SSMS.

# RetailOps — Enterprise Order & Inventory Management System

> **Business Analysis • Systems Analysis • Microsoft SQL Server • Testing • Power BI**  
> Portfolio case study | **Fictional multinational retail company** | 3 countries / 6 warehouses / 25 relational tables / 100,000 **synthetic** orders

![Logical ERD](assets/retailops_erd.png)

> **Current release status (v1.2 hotfix):** STATIC CHECKED, not yet executed or verified in SQL Server. If you downloaded v1.1 and saw SQL error 102 in `usp_CreateOrder`, replace and rerun `database/02_procedures.sql` using the [hotfix instructions](FIX_v1_2_SQL_PROCEDURES_SR.md). See [QUALITY_REVIEW.md](QUALITY_REVIEW.md) and [Windows deployment/GitHub guide](WINDOWS_SETUP_GITHUB_SR.md).

## Project overview

RetailOps demonstrates an end-to-end Business/System Analyst workflow: frame a business problem, elicit and prioritize hypothetical requirements, define measurable acceptance criteria, model TO-BE processes, design a normalized relational system, implement transactional SQL business rules, supply verification tests, and prepare a decision-oriented reporting layer.

### Business challenge (fictional case)

A retailer operating in **Serbia, Croatia and Slovenia** cannot reliably answer three questions: “Where is inventory available?”, “Can the next order be fulfilled without overselling?”, and “Which products/warehouses/carriers need action?” RetailOps centralizes available-to-promise stock and traceability.

### Why this is a Business Analyst portfolio project

| BA competency | Demonstration | Evidence |
|---|---|---|
| Business problem framing | Pain points, stakeholders, scope, proposed KPIs | `business-analysis/01_BRD.md` |
| Requirements and communication | 12 prioritized user stories + acceptance criteria | `business-analysis/02_user_stories_acceptance.md` |
| Modeling | ERD, BPMN 2.0 model, UML sequence | `system-design/` |
| Traceability | Requirements ↔ design ↔ SQL ↔ tests | `business-analysis/05_requirements_traceability.csv` |
| System design | 25 related tables, inventory vs reservation vs fulfillment | `database/01_schema.sql` |
| Engineering collaboration | Seven operational stored procedures and constraints | `database/02_procedures.sql` |
| Quality assurance | Positive, negative and concurrency test protocols | `testing/` |
| Data analysis | Five analytic views, 12 SQL business questions | `database/05_views.sql`, `analytics/` |
| Reporting and presentation | 3-page Power BI plan, DAX measures, interview presentation | `powerbi/`, `presentation/` |

## System design and key decisions

- **Atomic reservations:** `QuantityAvailable = QuantityOnHand - QuantityReserved`. During allocation, the procedure locks inventory rows and either commits all required reservations or rolls back the full order.
- **Domestic-first fulfillment:** Selects warehouses in the destination country first, then regional alternatives, and creates warehouse-scoped fulfillments (allowing split allocations).
- **Physical vs committed stock:** Order allocation increases reserved quantity only. Dispatch reduces physical and reserved stock and writes movement rows.
- **History and controls:** Prices/costs snapshotted per line; ledger and audit log; status checks and idempotency key for order creation (conflicting replay returns error 51009).
- **Reporting discipline:** Revenue views have explicit grain, qualify revenue by order status and subtract received returns; margin is a simplified gross margin proxy.

![TO-BE Process](assets/to_be_process.png)

## Quick start (SSMS / SQL Server Express)

**Requirements:** Microsoft SQL Server 2019+ (SQL Server 2025 Express supported), SQL Server Management Studio, permissions to create a local database, enough free disk space. Power BI Desktop is optional for report completion. **No real customer data is used.**

1. In SSMS, connect with `Windows Authentication` to `(.\SQLEXPRESS)` or the local instance name that works for you.
2. Open and execute the following files **in numerical order**, once each. Every file selects `USE RetailOpsDB` after the first script.

```text
database/00_create_database.sql
database/01_schema.sql
database/02_procedures.sql
database/03_seed_data.sql          <-- generates 100,000 fictional orders
database/04_indexes.sql
database/05_views.sql
database/06_demo_workflows.sql     <-- delivery, return, partial procurement
testing/04_post_install_validation.sql  <-- PASS V01–V07, read-only checks
```

3. Run `testing/04_post_install_validation.sql` to check the installed structure/data/ledger. Then run `testing/01_integration_tests.sql`. Expected: **PASS T01–T08** printed in *Messages*. Tests are designed to roll back test data. Then run `testing/02_negative_tests.sql` to validate rejected business scenarios (N01–N03).
4. Run `analytics/01_business_questions.sql` for executive, supplier, return, fulfillment and inventory analysis.
5. Optional: follow `powerbi/04_dashboard_design.md` to build the three-page report in Power BI Desktop.

**Note:** SQL Express may take time to generate 100k orders and historical ledger records. If errors arise, inspect the exact message and check which script completed before retrying. The initial scripts are **not designed to be reapplied to a partially created DB**; use a disposable fresh `RetailOpsDB` for full reinstallation. No script drops a database. See `WINDOWS_SETUP_GITHUB_SR.md` for exact Windows SSMS and GitHub Desktop steps.

### Fast system validation

```sql
USE RetailOpsDB;
SELECT COUNT(*) AS Orders FROM dbo.SalesOrders;
SELECT COUNT(*) AS OrderItems FROM dbo.SalesOrderItems;
SELECT COUNT(*) AS StockRows FROM dbo.Inventory;
SELECT COUNT(*) AS Shipments FROM dbo.Shipments;
SELECT TOP(10) * FROM dbo.vw_InventoryHealth WHERE StockHealth='REORDER';
```

Expected **before operational tests**: 100,000 synthetic historical orders plus one or more demo orders; order items and shipments are numerous. Do not treat these as real business volume.

## Directory map

```text
RetailOps_BA_Portfolio/
├── README.md, START_HERE_SR.md
├── business-analysis/
│   ├── 01_BRD.md
│   ├── 02_user_stories_acceptance.md
│   ├── 03_KPI_dictionary.md
│   ├── 04_stakeholder_RACI_risk.md
│   └── 05_requirements_traceability.csv
├── system-design/
│   ├── 00_SRS.md
│   ├── 01_ERD.dot / 01_ERD.md
│   ├── 02_process_to_be.bpmn / .dot
│   ├── 03_process_current_state.md
│   ├── 04_sequence_diagram.md
│   ├── 05_system_context.md
│   ├── 06_security_and_limits.md
│   └── 07_data_dictionary.md
├── database/                  -- database setup through demo, ordered
├── analytics/                 -- SQL questions and performance study
├── testing/                   -- integration, negative, concurrency, evidence templates
├── powerbi/                   -- M, DAX, theme JSON and detailed build plan
├── presentation/              -- interview script, slides
├── deliverables/              -- polished Word BRD/SRS and PowerPoint deck
├── assets/                    -- diagram previews
└── tools/                     -- editable diagram generator
```

## Example business demonstration

**Scenario:** A customer orders two units of product A and one unit of product B. Warehouse 1 can satisfy both. The allocation procedure reserves units with update locks, records reservation and a warehouse fulfillment; dispatch removes three physical units and writes movement ledger records; delivery updates status. A returned A is restocked at a designated processing warehouse and reflected in the sales fact view.

**Failure case:** An order requests more stock than exists across eligible warehouses. The allocation transaction raises error **51102** and fully rolls back its stock changes and reservations, leaving the order in NEW state for manual resolution. Concurrency test protocol demonstrates the last-unit scenario.

## KPIs and analytical questions

The included analysis addresses country revenue and margins, seasonal revenue, ABC SKU classification, current stockout risk, delivery lateness, open overdue shipments, returns, supplier performance, slow-moving inventory, backlog and customer purchase frequency. Report metric definitions are in `business-analysis/03_KPI_dictionary.md`.

### Power BI note

Included: **query definitions, 23+ DAX measures, theme and a detailed 3-page report design**. A binary `.pbix` is **not included**, because it must be built and validated in Power BI Desktop against a SQL Server instance. Please do not state that a working Power BI dashboard was built until you complete those steps.

## Validation status — important for recruiters

The GitHub Actions workflow only runs `tools/validate_bundle.py` to inspect file structure, named objects and markup. A green static-check build **does not mean** the SQL procedures or Power BI report were executed.

**Artifacts authored, but not executed on your Windows SQL Server instance in this environment.** The included scripts and tests are designed to run on SQL Server. A reproducible 100k-row generator is included, but **no benchmark, test pass, Power BI refresh or performance gain is claimed**. Test evidence templates start with `NOT RUN`. Once you've executed them, record actual results and screenshots before using in a CV.

Synthetic trends, business targets, client personas and requirements are fictional. This is a portfolio case, not a client engagement or Grid Dynamics commissioned project.

## Project constraints / deliberate tradeoffs

All report monetary data uses EUR-equivalent catalog values across all three countries. No VAT, FX, real accounting revenue recognition, carrier API, customer-facing API, permissions model, payment handling, production deployment, SQL integration CI/CD or backorder workflow is implemented. GitHub Actions includes **static bundle checks only** (not an SQL Server test runner). Procurement and return **approval** state entry is represented by seed/demo rows, not automated approval. See `system-design/00_SRS.md` for complete limitations.

## Suggested development narrative

1. Demonstrate requirement **FR-03** and acceptance **US-03**.
2. Walk through its SQL implementation and locks.
3. Run tests **T01, N01, C01** and collect results.
4. Open the TO-BE BPMN and compare to assumed AS-IS.
5. Show business questions and Power BI pages (once built).
6. Discuss the *next* real-client interviews, API security, FX/tax and operational data collection.

## Credits, references, and disclosure

Portfolio design approach is informed by [IIBA Business Analysis Standard](https://www.iiba.org/knowledgehub/the-business-analysis-standard/4-implementing-business-analysis/4-4-understanding-requirements-and-designs/) and [Microsoft SQL Server procedure guidance](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql). This is an independent educational simulation, not an official certification or employer assignment. AI assistance was used in drafting code, documentation and test scenarios; all results must be independently executed, reviewed, explained and verified before presentation as achieved work.

**License:** MIT for the portfolio code and original materials; fictional dataset only.

> **v1.6 maintenance note:** Use the corrected files in `testing/01_integration_tests.sql` and `testing/02_negative_tests.sql`. The first six validation checks plus the standalone optimized V07 were verified on the local demo dataset; full integration-suite execution remains pending.


### T01 test fix (v1.7)

In `testing/01_integration_tests.sql`, qualify the reservation amount with `r.Quantity` in the T01 allocation check. After v1.6 runs, test T01 independently using the companion `RetailOps_T01_only_v1_7.sql` if needed. A prior run confirmed T02–T08 PASS; T01 requires a separate successful execution before marking it PASS.

> **v1.8 test note:** negative tests use JSON variables before `EXEC`. If N02 already passed, run only `RetailOps_N01_N03_only_v1_8.sql` to verify N01/N03. Results are pending until run in SSMS.


## Concurrency validation (two SSMS sessions)

For a controlled two-session stock reservation scenario, use `testing/03_concurrency_manual.md` and `testing/concurrency/01_setup.sql` through `04_verify_and_cleanup.sql`. Do not edit inventory directly. This manual test has not been confirmed on the user’s SQL Server until its run outputs have been captured.
