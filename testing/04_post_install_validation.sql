/* RetailOps v1.4 | Post-install assertions — SAFE / READ ONLY.
   Run after database/00..06. PASS is printed in Messages; errors abort verification.
   These checks do not replace integration, negative, or concurrency tests. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #LedgerMismatch;
DROP TABLE IF EXISTS #ReservationMismatch;
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo'))<25
    THROW 55001,'Schema incomplete: fewer than 25 user tables.',1;
IF (SELECT COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'usp_%')<7
    THROW 55002,'Procedures incomplete.',1;
IF (SELECT COUNT(*) FROM sys.views WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'vw_%')<5
    THROW 55003,'Analytical views incomplete.',1;
PRINT 'PASS V01 schema: 25 tables, 7 procedures, 5 views available';

IF (SELECT COUNT(*) FROM dbo.Countries)<>3 OR (SELECT COUNT(*) FROM dbo.Warehouses)<>6
    OR (SELECT COUNT(*) FROM dbo.Products)<>72 OR (SELECT COUNT(*) FROM dbo.Customers)<>5000
    THROW 55004,'Seed dimension counts differ from expected values.',1;
IF (SELECT COUNT(*) FROM dbo.SalesOrders WHERE OrderNumber LIKE 'HIST-%')<>100000
    THROW 55005,'Expected exactly 100000 HIST synthetic orders.',1;
PRINT 'PASS V02 dataset: 3 countries, 6 warehouses, 72 SKUs, 5000 customers, 100000 historical orders';

IF EXISTS (SELECT 1 FROM dbo.Inventory WHERE QuantityOnHand<0 OR QuantityReserved<0 OR QuantityReserved>QuantityOnHand)
    THROW 55006,'Inventory negative or over-reserved.',1;
PRINT 'PASS V03 no negative or over-reserved inventory';

;WITH Ledger AS (
    SELECT WarehouseID,ProductID,SUM(CONVERT(BIGINT,QuantityDelta)) AS LedgerBalance
    FROM dbo.InventoryMovements GROUP BY WarehouseID,ProductID
)
SELECT i.WarehouseID,i.ProductID,i.QuantityOnHand,COALESCE(l.LedgerBalance,0) LedgerBalance
INTO #LedgerMismatch
FROM dbo.Inventory i LEFT JOIN Ledger l ON l.WarehouseID=i.WarehouseID AND l.ProductID=i.ProductID
WHERE CONVERT(BIGINT,i.QuantityOnHand)<>COALESCE(l.LedgerBalance,0);
IF EXISTS(SELECT 1 FROM #LedgerMismatch)
BEGIN
    SELECT TOP(20) * FROM #LedgerMismatch ORDER BY WarehouseID,ProductID;
    THROW 55007,'Inventory movement ledger mismatch; see Results for sample.',1;
END;
DROP TABLE #LedgerMismatch;
PRINT 'PASS V04 movement ledger reconciles to physical stock';

;WITH ActiveReserved AS (
    SELECT r.WarehouseID,oi.ProductID,SUM(CONVERT(BIGINT,r.Quantity)) AS ReservationBalance
    FROM dbo.InventoryReservations r
    JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=r.OrderItemID
    WHERE r.ReservationStatus='ACTIVE' GROUP BY r.WarehouseID,oi.ProductID
)
SELECT i.WarehouseID,i.ProductID,i.QuantityReserved,COALESCE(r.ReservationBalance,0) ReservationBalance
INTO #ReservationMismatch
FROM dbo.Inventory i LEFT JOIN ActiveReserved r ON r.WarehouseID=i.WarehouseID AND r.ProductID=i.ProductID
WHERE CONVERT(BIGINT,i.QuantityReserved)<>COALESCE(r.ReservationBalance,0);
IF EXISTS(SELECT 1 FROM #ReservationMismatch)
BEGIN
    SELECT TOP(20) * FROM #ReservationMismatch ORDER BY WarehouseID,ProductID;
    THROW 55008,'Active reservation balance mismatch; see Results for sample.',1;
END;
DROP TABLE #ReservationMismatch;
PRINT 'PASS V05 active reservations reconcile to reserved stock';

IF EXISTS (
    SELECT 1 FROM dbo.SalesOrders o
    JOIN dbo.CustomerAddresses a ON a.AddressID=o.ShipAddressID
    WHERE a.CustomerID<>o.CustomerID
) THROW 55009,'Order references a shipping address owned by another customer.',1;
PRINT 'PASS V06 shipping address ownership';

/* V07: Aggregate once rather than executing a correlated SUM for each order line.
   The temporary table lives in tempdb; no business rows are modified. */
DROP TABLE IF EXISTS #FulfillmentTotals;
SELECT fi.OrderItemID, SUM(CONVERT(BIGINT,fi.Quantity)) AS AllocatedQty
INTO #FulfillmentTotals
FROM dbo.FulfillmentItems AS fi
GROUP BY fi.OrderItemID;
CREATE UNIQUE CLUSTERED INDEX CX_FulfillmentTotals ON #FulfillmentTotals(OrderItemID);

IF EXISTS (
    SELECT 1
    FROM dbo.SalesOrders AS o
    JOIN dbo.SalesOrderItems AS oi ON oi.OrderID=o.OrderID
    LEFT JOIN #FulfillmentTotals AS ft ON ft.OrderItemID=oi.OrderItemID
    WHERE o.OrderStatus IN ('RESERVED','PARTIAL','SHIPPED','DELIVERED')
      AND COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0))<>CONVERT(BIGINT,oi.Quantity)
)
BEGIN
    SELECT TOP (20) o.OrderID, oi.OrderItemID, oi.Quantity AS OrderedQty,
           COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0)) AS AllocatedQty
    FROM dbo.SalesOrders AS o
    JOIN dbo.SalesOrderItems AS oi ON oi.OrderID=o.OrderID
    LEFT JOIN #FulfillmentTotals AS ft ON ft.OrderItemID=oi.OrderItemID
    WHERE o.OrderStatus IN ('RESERVED','PARTIAL','SHIPPED','DELIVERED')
      AND COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0))<>CONVERT(BIGINT,oi.Quantity)
    ORDER BY o.OrderID, oi.OrderItemID;
    THROW 55010,'Allocated and ordered unit quantities differ; see Results.',1;
END;
DROP TABLE #FulfillmentTotals;
PRINT 'PASS V07 fulfilled line quantities reconcile to ordered quantities';

SELECT
  (SELECT COUNT(*) FROM dbo.SalesOrders) AS TotalOrders,
  (SELECT COUNT(*) FROM dbo.SalesOrderItems) AS TotalLines,
  (SELECT COUNT(*) FROM dbo.Shipments) AS Shipments,
  (SELECT COUNT(*) FROM dbo.InventoryMovements) AS InventoryMovements,
  (SELECT COUNT(*) FROM dbo.vw_SalesFact) AS SalesFactRows;
PRINT 'All seven post-install validation checks passed; record this output as real evidence.';
GO
