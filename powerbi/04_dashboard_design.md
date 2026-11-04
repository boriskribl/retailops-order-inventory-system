# Power BI — implemented report and reproducibility guide

**Artifact:** `RetailOps_Operations_Dashboard.pbix` — a three-page Power BI Desktop report built locally using **five** SQL reporting views, not a design-only kit. Supporting screenshots are in `assets/`. The dataset is synthetic.

## Connection / refresh on a fresh machine

1. Install and populate a new disposable `RetailOpsDB` by following the repo `README.md`. Do **not** rerun the seed script on an existing database.
2. Open the included `.pbix` in Power BI Desktop.
3. Select **Transform data → Data source settings** and change the SQL Server source to the machine's local instance (e.g. `.\SQLEXPRESS`), database `RetailOpsDB`, Windows Authentication / Import mode.
4. Verify the five loaded logical tables and backing views:

| Power BI table | SQL view |
|---|---|
| `DailySales` | `dbo.vw_DailySales` |
| `Sales` | `dbo.vw_SalesFact` |
| `Inventory` | `dbo.vw_InventoryHealth` |
| `Fulfillment` | `dbo.vw_FulfillmentPerformance` |
| `Procurement` | `dbo.vw_ProcurementPerformance` |

5. Refresh data. The report was created with Power BI's **Auto date/time disabled** to avoid a local relationship/cyclic-reference issue encountered during build.
6. Check visuals, labels, measures and reconciliation to SQL. The `02_DAX_measures.dax` file is a *reference library*, not necessarily an exact export of every measure in the PBIX.

## Page 1 — Sales Performance

**Implemented:** Cards showing total ordered value (excluding cancelled orders), net revenue, orders placed, delivered orders; monthly order trend; country sales comparison; online vs store sales-channel donut; country and order-date slicers.

**Key definition:** `DailySales[OrderedValueEUR]` excludes cancelled orders in the SQL view. Raw order-line `Sales[OrderedValueEUR]` does not; any DAX aggregation over the granular Sales table must filter `Sales[OrderStatus] <> "CANCELLED"` to match the reporting KPI. `AllOrders` still includes cancelled orders.

**Design improvement:** The 100k-order seed and test scenarios can create striking synthetic monthly changes. Explain those as synthetic generator artifacts rather than demand forecasts.

## Page 2 — Inventory & Supply Chain

**Implemented:** Total/available/reserved stock and count of low-stock warehouse-product rows; available stock by warehouse; low-stock table; procurement totals and supplier comparison.

**Observation:** 30 warehouse-product rows at/below their reorder points were observed locally. One product showed zero stock in several warehouse rows; review planned replenishment before proposing changes to reorder policy. Procurement fulfillment should be displayed in percentage format, not as a raw fraction.

## Page 3 — Order Fulfillment

**Implemented:** Total and delivered shipments; on-time-delivery percentage (about 80% in this synthetic sample); average delivery days (about 2.60); delivered shipments by country; status split; carrier comparison.

**Interpretation caution:** Similar carrier on-time results reflect simulated distribution; no real carrier ranking is justified.

## Acceptance / release checks

- [x] Report .pbix created and committed.
- [x] Three page screenshots created and committed.
- [x] Local refresh reported working after correcting date/time settings.
- [x] KPI results cross-checked with local SQL examples.
- [ ] Fresh-machine data source repointing, refresh and external reproduction not independently confirmed.
- [ ] Full visual presentation review, labels and percent formats to be polished.

## Reporting limitations

All sales, inventory, procurement and shipment records are synthetic. EUR prices, margins, shipment SLA and replenishment rules are educational assumptions, not validated client policies. Power BI Service sharing, row-level security, incremental refresh and real-time integrations are not implemented.
