/* RetailOps v1.4 — fast V07 only. Read-only business data. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #FulfillmentTotals;
SELECT fi.OrderItemID, SUM(CONVERT(BIGINT,fi.Quantity)) AS AllocatedQty
INTO #FulfillmentTotals
FROM dbo.FulfillmentItems AS fi
GROUP BY fi.OrderItemID;
CREATE UNIQUE CLUSTERED INDEX CX_FulfillmentTotals ON #FulfillmentTotals(OrderItemID);

SELECT COUNT_BIG(*) AS MismatchCount
FROM dbo.SalesOrders AS o
JOIN dbo.SalesOrderItems AS oi ON oi.OrderID=o.OrderID
LEFT JOIN #FulfillmentTotals AS ft ON ft.OrderItemID=oi.OrderItemID
WHERE o.OrderStatus IN ('RESERVED','PARTIAL','SHIPPED','DELIVERED')
  AND COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0))<>CONVERT(BIGINT,oi.Quantity);

SELECT TOP (20) o.OrderID, oi.OrderItemID, oi.Quantity AS OrderedQty,
       COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0)) AS AllocatedQty
FROM dbo.SalesOrders AS o
JOIN dbo.SalesOrderItems AS oi ON oi.OrderID=o.OrderID
LEFT JOIN #FulfillmentTotals AS ft ON ft.OrderItemID=oi.OrderItemID
WHERE o.OrderStatus IN ('RESERVED','PARTIAL','SHIPPED','DELIVERED')
  AND COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0))<>CONVERT(BIGINT,oi.Quantity)
ORDER BY o.OrderID, oi.OrderItemID;
DROP TABLE #FulfillmentTotals;
GO
