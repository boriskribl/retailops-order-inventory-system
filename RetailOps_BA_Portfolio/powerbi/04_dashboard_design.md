# Power BI dashboard specification and build guide

**Deliverable:** documented *report build kit*, not a built `.pbix`. Power BI Desktop runs on your Windows computer and must connect to your local SQL Server instance. Import the four reporting views and paste DAX measures as described below.

## 1. Connection steps

1. Open Power BI Desktop → **Get data → SQL Server**.
2. Server: `.\SQLEXPRESS` (or the full `DESKTOP-…\SQLEXPRESS` shown in SSMS). Database: `RetailOpsDB`.
3. **Import** mode, Windows credentials. Choose `dbo.vw_SalesFact`, `dbo.vw_InventoryHealth`, `dbo.vw_FulfillmentPerformance`, and `dbo.vw_ProcurementPerformance`. Rename queries to **Sales**, **Inventory**, **Fulfillment**, **Procurement** respectively. Use `01_PowerQuery_M.pq` for the equivalent explicit Power Query paths if desired.
4. Import `Countries` and rename to **DimCountry**. Create 1:* relationships from `DimCountry[ISOCode]` to `Sales[DestinationCountry]`, `Inventory[Country]`, and `Fulfillment[DestinationCountry]` (single direction).
5. Power BI **Model view**: mark/date `Sales[OrderDate]` type Date; build a Calendar table for Date to Sales[OrderDate]. Avoid joining fact-to-fact views.
6. Create one DAX measure at a time from `02_DAX_measures.dax`. Format EUR measures as `€#,##0`, percentages as `0.0%`, inventory counts as whole numbers.
7. View → Themes → Browse for themes → import `03_RetailOps_theme.json`.
8. Build the three pages below. Then save as `RetailOps_Operations_Dashboard.pbix` in this folder, create screenshots and commit only non-sensitive examples to GitHub.

## 2. Page 1 — Sales Performance

**Question:** Which markets and product categories generate value, and what is the cost of returns?

| Position | Visual | Data |
|---|---|---|
| Top row | KPI cards | Net Revenue EUR, Net Margin %, Delivered Orders, Return Rate % |
| Main left | Line chart | Calendar[Date] by Net Revenue EUR, drill to Month |
| Main right | Clustered bar | Sales[DestinationCountry] vs Net Revenue EUR |
| Bottom left | Horizontal bar | Sales[CategoryName] vs Net Revenue EUR |
| Bottom right | Matrix | SKU/ProductName vs revenue / margin / returns |
| Slicers | Country, date, sales channel | DimCountry[ISOCode], Calendar, Sales[SalesChannel] |

**Suggested insight prompts:** Which market has the highest return-adjusted revenue? Which categories have thin margins? Do seasonal peaks reflect genuine data or the synthetic generation design?

## 3. Page 2 — Inventory & Supply Chain

**Question:** Where are stockouts likely, and where is capital tied up?

| Position | Visual | Data |
|---|---|---|
| Top | KPI cards | Available Units, Inventory Value EUR, Low Stock SKU Locations, Outstanding PO Units |
| Middle left | Matrix, conditional colors | WarehouseCode × ProductName, AvailableQty |
| Middle right | Bar | WarehouseCode vs InventoryValueEUR |
| Bottom left | Table | SKU / Warehouse / Available / ReorderPoint / flag REORDER |
| Bottom right | Bar | SupplierName vs OutstandingQty |

**Caution:** Product inventory costs use current catalogue standard costs. They are illustrative, not audited inventory valuation.

## 4. Page 3 — Fulfillment & Service

**Question:** What is the on-time delivery rate, and which carrier/market needs intervention?

| Position | Visual | Data |
|---|---|---|
| Top | KPI cards | Delivered Shipments, On Time Delivery %, Average Delivery Hours, Overdue Open Shipments |
| Middle left | Bar | CarrierName vs On Time Delivery % |
| Middle right | Matrix | DestinationCountry × CarrierName, delivery %, delivered shipments |
| Bottom | Table | ShipmentID, WarehouseCode, ExpectedDeliveryAt, DeliveredAt, OverdueOpenFlag |

**Slicers:** DimCountry[ISOCode], CarrierName, ShipmentStatus. These allow operational exception exploration.

## 5. Business insight slide (do not claim unmeasured facts)

After importing and refreshing against your own SQL instance, capture 3 genuinely computed findings and proposed actions. Suggested format:

- **Observed on your synthetic dataset:** e.g. “Low-stock status concentrated in X SKUs across Y warehouses.” Add screenshot and query evidence.
- **Hypothesis:** “Lower reorder points for slow movers / increase buffer for high-demand items.”
- **Recommendation:** Pilot threshold adjustment, monitor available stock and supplier lead time.
- **Limitations:** Synthetic data, fixed routing rules, no real transaction volume, no economic causal test.

## 6. Acceptance checklist

- [ ] All four reporting views load and Refresh completes without errors.
- [ ] Sales row count equals `SELECT COUNT(*) FROM dbo.vw_SalesFact`.
- [ ] Country slicer filters Sales, Inventory and Fulfillment (via DimCountry).
- [ ] Total Net Revenue in Power BI equals the SQL sum from `vw_SalesFact`.
- [ ] Delivered Orders uses distinct ID count, not order line count.
- [ ] Return Rate counts returned units against delivered units, not all placed units.
- [ ] Screenshots include synthetic-data disclosure and date of refresh.
- [ ] `.pbix` saved and screenshots committed if you choose to publish them.

## 7. Stretch goals

Add role-playing dates for shipment delivery, drillthrough to OrderID (via SQL), reorder action recommendations, incremental refresh for larger datasets, and a reconciliation/data-quality page. These are **not implemented** in this project bundle.
