/* RetailOps: business questions translated into SQL insight. Read-only queries. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
-- Q01. Executive overview (EUR; delivered only for recognized revenue)
SELECT COUNT(DISTINCT OrderID) AS OrdersPlaced,
 SUM(CASE WHEN OrderStatus='DELIVERED' THEN NetRevenueEUR ELSE 0 END) AS NetRevenueEUR,
 SUM(NetMarginEUR) AS NetMarginEUR,
 SUM(ReturnedValueEUR) AS RefundedValueEUR
FROM dbo.vw_SalesFact;

-- Q02. Regional revenue, margins, returns, and ranking (window functions)
WITH Region AS (
 SELECT DestinationCountry,SUM(NetRevenueEUR) RevenueEUR,SUM(NetMarginEUR) MarginEUR,
        SUM(ReturnedValueEUR) ReturnsEUR
 FROM dbo.vw_SalesFact GROUP BY DestinationCountry
)
SELECT DestinationCountry,RevenueEUR,MarginEUR,ReturnsEUR,
 CONVERT(DECIMAL(6,2),100.0*MarginEUR/NULLIF(RevenueEUR,0)) MarginPct,
 DENSE_RANK() OVER(ORDER BY RevenueEUR DESC) RevenueRank
FROM Region ORDER BY RevenueRank;

-- Q03. Monthly revenue and three-month moving average
WITH Monthly AS (
 SELECT DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1) MonthStart,
 SUM(NetRevenueEUR) RevenueEUR FROM dbo.vw_SalesFact GROUP BY YEAR(OrderDate),MONTH(OrderDate)
)
SELECT MonthStart,RevenueEUR,
 AVG(RevenueEUR) OVER(ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) Avg3Months,
 SUM(RevenueEUR) OVER(ORDER BY MonthStart ROWS UNBOUNDED PRECEDING) CumulativeRevenue
FROM Monthly ORDER BY MonthStart;

-- Q04. ABC product classification based on contribution to revenue
WITH Sales AS (
 SELECT SKU,ProductName,SUM(NetRevenueEUR) Revenue FROM dbo.vw_SalesFact
 GROUP BY SKU,ProductName
), Cumulative AS (
 SELECT *,SUM(Revenue) OVER(ORDER BY Revenue DESC,SKU) RunningRevenue,
 SUM(Revenue) OVER() TotalRevenue FROM Sales
)
SELECT SKU,ProductName,Revenue,
 CONVERT(DECIMAL(6,2),100.0*RunningRevenue/NULLIF(TotalRevenue,0)) CumulativePct,
 CASE WHEN RunningRevenue<=0.8*TotalRevenue THEN 'A'
      WHEN RunningRevenue<=0.95*TotalRevenue THEN 'B' ELSE 'C' END ABCClass
FROM Cumulative ORDER BY Revenue DESC;

-- Q05. Potential stockouts / reorder suggestions (current snapshot)
SELECT Country,WarehouseCode,SKU,ProductName,AvailableQty,ReorderPoint,ReorderQuantity,InventoryValueEUR
FROM dbo.vw_InventoryHealth WHERE StockHealth='REORDER'
ORDER BY AvailableQty,WarehouseCode;

-- Q06. Late delivery by carrier and market (delivered shipments only)
SELECT CarrierName,DestinationCountry,COUNT(*) DeliveredShipments,
 SUM(CASE WHEN OnTimeDeliveredFlag=1 THEN 1 ELSE 0 END) OnTimeCount,
 CONVERT(DECIMAL(5,2),100.0*AVG(CONVERT(FLOAT,OnTimeDeliveredFlag))) OnTimePercent,
 AVG(CONVERT(DECIMAL(18,2),DeliveryHours)) AvgDeliveryHours
FROM dbo.vw_FulfillmentPerformance WHERE ShipmentStatus='DELIVERED'
GROUP BY CarrierName,DestinationCountry ORDER BY OnTimePercent ASC;

-- Q07. Open shipments that missed their promised delivery date
SELECT ShipmentID,OrderID,CarrierName,DestinationCountry,ExpectedDeliveryAt,
 DATEDIFF(DAY,ExpectedDeliveryAt,SYSUTCDATETIME()) DaysOverdue
FROM dbo.vw_FulfillmentPerformance WHERE OverdueOpenFlag=1 ORDER BY DaysOverdue DESC;

-- Q08. Return rates (units), by category
SELECT CategoryName,SUM(ReturnedQty) ReturnedUnits,
 SUM(CASE WHEN OrderStatus='DELIVERED' THEN Quantity ELSE 0 END) DeliveredUnits,
 CONVERT(DECIMAL(6,2),100.0*SUM(ReturnedQty)/NULLIF(SUM(CASE WHEN OrderStatus='DELIVERED' THEN Quantity ELSE 0 END),0)) ReturnRatePct
FROM dbo.vw_SalesFact GROUP BY CategoryName ORDER BY ReturnRatePct DESC;

-- Q09. Slow-moving inventory (no sales shipment in the last 90 days)
SELECT i.WarehouseCode,i.SKU,i.AvailableQty,i.InventoryValueEUR
FROM dbo.vw_InventoryHealth i WHERE i.QuantityOnHand>0
AND NOT EXISTS (
 SELECT 1 FROM dbo.InventoryMovements m
 WHERE m.WarehouseID=i.WarehouseID AND m.ProductID=i.ProductID
 AND m.MovementType='SALE' AND m.OccurredAt>=DATEADD(DAY,-90,SYSUTCDATETIME())
) ORDER BY i.InventoryValueEUR DESC;

-- Q10. Supplier quality / outstanding receiving quantity
SELECT SupplierName,SUM(QuantityOrdered) OrderedUnits,SUM(ReceivedQty) ReceivedUnits,
 SUM(OutstandingQty) OutstandingUnits,
 AVG(CASE WHEN OnTimeReceiptFlag IS NOT NULL THEN CONVERT(FLOAT,OnTimeReceiptFlag) END) OnTimeFraction
FROM dbo.vw_ProcurementPerformance GROUP BY SupplierName ORDER BY OutstandingUnits DESC;

-- Q11. NEW/RESERVED/PARTIAL order backlog by destination country
SELECT DestinationCountry,OrderStatus,COUNT(DISTINCT OrderID) OrdersInState,
 SUM(OrderedValueEUR) BacklogValueEUR
FROM dbo.vw_SalesFact
WHERE OrderStatus IN ('NEW','RESERVED','PARTIAL','SHIPPED')
GROUP BY DestinationCountry,OrderStatus ORDER BY BacklogValueEUR DESC;

-- Q12. Customer repeat purchase frequency (RFM-like indicator)
WITH CustomerOrders AS (
 SELECT CustomerID,COUNT(DISTINCT OrderID) DeliveredOrders,MAX(OrderDate) LastOrder,
 SUM(NetRevenueEUR) RevenueEUR
 FROM dbo.vw_SalesFact WHERE OrderStatus='DELIVERED' GROUP BY CustomerID
)
SELECT TOP(30) CustomerID,DeliveredOrders,LastOrder,RevenueEUR,
 DATEDIFF(DAY,LastOrder,CONVERT(DATE,SYSUTCDATETIME())) DaysSinceLastOrder
FROM CustomerOrders ORDER BY RevenueEUR DESC;
GO
