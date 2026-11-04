# KPI and metric dictionary

## Critical grain and source rules

- `vw_SalesFact`: **one row per SalesOrderItem**, not per order.
- `vw_InventoryHealth`: **one row per (Warehouse, Product)** at query time (snapshot).
- `vw_FulfillmentPerformance`: **one row per shipment / fulfillment**.
- `vw_ProcurementPerformance`: **one row per purchase-order line**.
- All prices/costs are deliberately stored in **EUR equivalent** for cross-market demonstration. NO currency exchange conversion or VAT treatment is implemented.

| Metric | Definition / formula | Report filter / unit | Source |
|---|---|---|---|
| Orders placed | Distinct order IDs | Includes all statuses; count | SalesFact |
| Delivered orders | Distinct order IDs with status DELIVERED | Delivered only; count | SalesFact |
| Gross ordered value | Sum(Quantity × price snapshot) | All order statuses; EUR | SalesFact.OrderedValueEUR |
| Recognized revenue | Sum(Quantity × price) when whole order DELIVERED | Delivered only; EUR | SalesFact.RecognizedRevenueEUR |
| Returned value | Sum(received-return quantity × original price) | Delivered orders only; EUR | SalesFact.ReturnedValueEUR |
| **Net revenue** | Recognized revenue − returned value | Delivered orders; EUR | SalesFact.NetRevenueEUR |
| Net gross margin | Sum((delivered units − returned units) × (price − cost snapshot)) | Fictional gross margin proxy; EUR | SalesFact.NetMarginEUR |
| Margin % | Net margin / net revenue | 0 if denominator is zero; % | BI measure |
| Units return rate | Received return units / delivered units | Units; % | SalesFact |
| Available-to-promise | On-hand − reserved | Warehouse/product; units | InventoryHealth |
| Inventory value | On-hand × product standard unit cost | EUR, estimated book proxy only | InventoryHealth |
| Reorder flag | Available <= reorder point | Warehouse/product | InventoryHealth |
| On-time delivery % | Delivered shipments arriving by expected timestamp / all delivered shipments | Shipments; % | FulfillmentPerformance |
| Average delivery hours | Mean(DeliveredAt − ShippedAt) | Delivered shipments; hours | FulfillmentPerformance |
| Overdue open shipments | Count(IN_TRANSIT where expected time < current UTC) | Count | FulfillmentPerformance |
| PO outstanding units | QuantityOrdered − SUM(GoodsReceipts.QuantityReceived) | Units per PO item | ProcurementPerformance |

## DAX modeling guidance

Use a dedicated `DimCountry` lookup (`Countries`, ISOCode) rather than relating fact-to-fact tables. A date table may relate to `Sales[OrderDate]`; if you also want shipment-date filtering, use a separate role-playing date table or separate measures. Power BI import refresh is a deliberate manual step; this bundle does not contain a functioning `.pbix`.

## Interpreting synthetic results

- Seasonal spikes were **deliberately encoded** in the fake order generation. They are not discovered business trends.
- All historical dispatches are modeled from simplified predefined rules; missing real courier data is not evidence of actual service performance.
- On-time thresholds are fabricated as scenario parameters.
- The return-rate data is generated on a repeating arithmetic pattern, not real consumer behavior.
- The model's per-order delivery revenue policy is for a portfolio illustration, not production revenue recognition or financial advice.
