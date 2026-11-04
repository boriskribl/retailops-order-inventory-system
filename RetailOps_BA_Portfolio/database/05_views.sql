/* RetailOps | 05 | Report-ready semantic views.
   SALES FACT GRAIN = one sales order line. Reporting currency is EUR for every country.
   This is a deliberate simplified planning assumption, not an FX conversion engine. */
USE RetailOpsDB;
GO
CREATE OR ALTER VIEW dbo.vw_SalesFact
AS
WITH Returned AS (
 SELECT ri.OrderItemID,SUM(ri.Quantity) ReturnedQty
 FROM dbo.ReturnItems ri JOIN dbo.ReturnRequests rr ON rr.ReturnID=ri.ReturnID
 WHERE rr.ReturnStatus='RECEIVED'
 GROUP BY ri.OrderItemID
)
SELECT o.OrderID,o.OrderNumber,o.OrderedAt,CAST(o.OrderedAt AS DATE) OrderDate,
       o.SalesChannel,o.OrderStatus,co.ISOCode DestinationCountry,
       co.CountryName,ci.CityName,c.CustomerID,p.ProductID,p.SKU,p.ProductName,cat.CategoryName,
       oi.OrderItemID,oi.Quantity,oi.UnitPriceEUR,oi.UnitCostEUR,
       COALESCE(r.ReturnedQty,0) ReturnedQty,
       CONVERT(DECIMAL(18,2),oi.Quantity*oi.UnitPriceEUR) OrderedValueEUR,
       CONVERT(DECIMAL(18,2),CASE WHEN o.OrderStatus='DELIVERED' THEN oi.Quantity*oi.UnitPriceEUR ELSE 0 END) RecognizedRevenueEUR,
       CONVERT(DECIMAL(18,2),CASE WHEN o.OrderStatus='DELIVERED' THEN COALESCE(r.ReturnedQty,0)*oi.UnitPriceEUR ELSE 0 END) ReturnedValueEUR,
       CONVERT(DECIMAL(18,2),CASE WHEN o.OrderStatus='DELIVERED' THEN (oi.Quantity-COALESCE(r.ReturnedQty,0))*oi.UnitPriceEUR ELSE 0 END) NetRevenueEUR,
       CONVERT(DECIMAL(18,2),CASE WHEN o.OrderStatus='DELIVERED' THEN (oi.Quantity-COALESCE(r.ReturnedQty,0))*(oi.UnitPriceEUR-oi.UnitCostEUR) ELSE 0 END) NetMarginEUR
FROM dbo.SalesOrderItems oi JOIN dbo.SalesOrders o ON o.OrderID=oi.OrderID
JOIN dbo.Customers c ON c.CustomerID=o.CustomerID
JOIN dbo.CustomerAddresses a ON a.AddressID=o.ShipAddressID
JOIN dbo.Cities ci ON ci.CityID=a.CityID
JOIN dbo.Countries co ON co.CountryID=ci.CountryID
JOIN dbo.Products p ON p.ProductID=oi.ProductID
JOIN dbo.Categories cat ON cat.CategoryID=p.CategoryID
LEFT JOIN Returned r ON r.OrderItemID=oi.OrderItemID;
GO
CREATE OR ALTER VIEW dbo.vw_InventoryHealth
AS
SELECT i.WarehouseID,w.WarehouseCode,co.ISOCode Country,i.ProductID,p.SKU,p.ProductName,
       p.CategoryID,i.QuantityOnHand,i.QuantityReserved,
       i.QuantityOnHand-i.QuantityReserved AvailableQty,p.ReorderPoint,p.ReorderQuantity,
       CASE WHEN i.QuantityOnHand-i.QuantityReserved<=p.ReorderPoint THEN 'REORDER' ELSE 'HEALTHY' END StockHealth,
       CONVERT(DECIMAL(18,2),i.QuantityOnHand*p.UnitCostEUR) InventoryValueEUR
FROM dbo.Inventory i JOIN dbo.Warehouses w ON w.WarehouseID=i.WarehouseID
JOIN dbo.Cities ci ON ci.CityID=w.CityID JOIN dbo.Countries co ON co.CountryID=ci.CountryID
JOIN dbo.Products p ON p.ProductID=i.ProductID;
GO
CREATE OR ALTER VIEW dbo.vw_FulfillmentPerformance
AS
SELECT s.ShipmentID,f.OrderID,f.WarehouseID,w.WarehouseCode,s.CarrierID,cr.CarrierName,
       co.ISOCode DestinationCountry,s.ShipmentStatus,s.ShippedAt,s.ExpectedDeliveryAt,s.DeliveredAt,
       CASE WHEN s.DeliveredAt IS NULL THEN NULL
            WHEN s.DeliveredAt<=s.ExpectedDeliveryAt THEN 1 ELSE 0 END OnTimeDeliveredFlag,
       CASE WHEN s.DeliveredAt IS NULL THEN NULL
            ELSE DATEDIFF(HOUR,s.ShippedAt,s.DeliveredAt) END DeliveryHours,
       CASE WHEN s.ShipmentStatus='IN_TRANSIT' AND s.ExpectedDeliveryAt<SYSUTCDATETIME() THEN 1 ELSE 0 END OverdueOpenFlag
FROM dbo.Shipments s JOIN dbo.OrderFulfillments f ON f.FulfillmentID=s.FulfillmentID
JOIN dbo.SalesOrders o ON o.OrderID=f.OrderID
JOIN dbo.CustomerAddresses a ON a.AddressID=o.ShipAddressID
JOIN dbo.Cities ci ON ci.CityID=a.CityID JOIN dbo.Countries co ON co.CountryID=ci.CountryID
JOIN dbo.Warehouses w ON w.WarehouseID=f.WarehouseID
JOIN dbo.Carriers cr ON cr.CarrierID=s.CarrierID;
GO
CREATE OR ALTER VIEW dbo.vw_ProcurementPerformance
AS
WITH ReceiptAgg AS (
 SELECT PurchaseOrderItemID,SUM(QuantityReceived) ReceivedQty,MAX(ReceivedAt) LastReceiptAt
 FROM dbo.GoodsReceipts GROUP BY PurchaseOrderItemID
)
SELECT po.PurchaseOrderID,po.PurchaseOrderNumber,po.PurchaseStatus,po.OrderedAt,po.ExpectedAt,
       s.SupplierID,s.SupplierName,po.WarehouseID,pi.PurchaseOrderItemID,pi.ProductID,
       pi.QuantityOrdered,COALESCE(r.ReceivedQty,0) ReceivedQty,
       pi.QuantityOrdered-COALESCE(r.ReceivedQty,0) OutstandingQty,
       pi.UnitCostEUR,CONVERT(DECIMAL(18,2),pi.QuantityOrdered*pi.UnitCostEUR) OrderedCostEUR,
       r.LastReceiptAt,CASE WHEN r.LastReceiptAt IS NULL OR po.ExpectedAt IS NULL THEN NULL
                         WHEN r.LastReceiptAt<=po.ExpectedAt THEN 1 ELSE 0 END OnTimeReceiptFlag
FROM dbo.PurchaseOrderItems pi JOIN dbo.PurchaseOrders po ON po.PurchaseOrderID=pi.PurchaseOrderID
JOIN dbo.Suppliers s ON s.SupplierID=po.SupplierID
LEFT JOIN ReceiptAgg r ON r.PurchaseOrderItemID=pi.PurchaseOrderItemID;
GO
CREATE OR ALTER VIEW dbo.vw_DailySales
AS
SELECT OrderDate,DestinationCountry,SalesChannel,
       COUNT(DISTINCT CASE WHEN OrderStatus='DELIVERED' THEN OrderID END) DeliveredOrders,
       COUNT(DISTINCT OrderID) AllOrders,
       SUM(OrderedValueEUR) OrderedValueEUR,
       SUM(NetRevenueEUR) NetRevenueEUR,
       SUM(NetMarginEUR) NetMarginEUR,
       SUM(ReturnedValueEUR) ReturnedValueEUR
FROM dbo.vw_SalesFact
GROUP BY OrderDate,DestinationCountry,SalesChannel;
GO
PRINT 'Five analytical views ready.';
GO
