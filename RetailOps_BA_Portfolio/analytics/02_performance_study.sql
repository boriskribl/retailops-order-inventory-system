/* Performance study: capture actual IO/time and execution plan in SSMS.
   NOTE: Results are NOT pre-claimed; record real numbers after running.
   SSMS: Query > Include Actual Execution Plan (Ctrl+M). */
USE RetailOpsDB;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- Indexed predicate; compare with and without IX_Orders_OrderedAtStatus on a DEV copy only.
SELECT o.OrderID,o.OrderedAt,o.OrderStatus,oi.ProductID,oi.Quantity
FROM dbo.SalesOrders o JOIN dbo.SalesOrderItems oi ON oi.OrderID=o.OrderID
WHERE o.OrderedAt>='2025-11-01' AND o.OrderedAt<'2026-01-01'
  AND o.OrderStatus='DELIVERED';
-- Stock check with IX_Inventory_ByProduct
SELECT WarehouseID,ProductID,QuantityOnHand-QuantityReserved Available
FROM dbo.Inventory WHERE ProductID=13 AND QuantityOnHand>QuantityReserved;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
/* Record baseline/optimized numbers in testing/performance_results_template.csv.
   Index changes affect performance and lock contention; compare on same data/hardware. */
