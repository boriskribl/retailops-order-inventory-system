/* RetailOps | 03 | Fictional deterministic portfolio dataset.
   Approx 100,000 orders, 175,000 lines and 5,000 customers.
   Designed for a NEW, EMPTY RetailOpsDB, run ONCE after schema and procedures.
   May take several minutes on SQL Server Express; requires adequate disk space.
   No real customer information is used. SQL Server 2019+ compatible. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.SalesOrders) OR EXISTS(SELECT 1 FROM dbo.Products)
    THROW 52000,'Seed requires an empty RetailOpsDB. Do not run twice.',1;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;
INSERT INTO dbo.Countries(ISOCode,CountryName,CurrencyCode) VALUES
 ('RS',N'Serbia','RSD'),('HR',N'Croatia','EUR'),('SI',N'Slovenia','EUR');
INSERT INTO dbo.Cities(CountryID,CityName) VALUES
 (1,N'Belgrade'),(1,N'Novi Sad'),(1,N'Niš'),
 (2,N'Zagreb'),(2,N'Split'),(2,N'Rijeka'),
 (3,N'Ljubljana'),(3,N'Maribor'),(3,N'Koper');
INSERT INTO dbo.Stores(CityID,StoreCode,StoreName) VALUES
 (1,'RS-BG-01',N'Belgrade Center'),(2,'RS-NS-01',N'Novi Sad North'),
 (4,'HR-ZG-01',N'Zagreb Center'),(5,'HR-ST-01',N'Split Coast'),
 (7,'SI-LJ-01',N'Ljubljana Center'),(8,'SI-MB-01',N'Maribor Center');
INSERT INTO dbo.Warehouses(CityID,WarehouseCode,WarehouseName,CapacityUnits) VALUES
 (1,'WH-RS-BG',N'Belgrade DC',1000000),(2,'WH-RS-NS',N'Novi Sad DC',1000000),
 (4,'WH-HR-ZG',N'Zagreb DC',1000000),(5,'WH-HR-ST',N'Split DC',1000000),
 (7,'WH-SI-LJ',N'Ljubljana DC',1000000),(8,'WH-SI-MB',N'Maribor DC',1000000);
INSERT INTO dbo.Categories(CategoryName) VALUES
 (N'Electronics'),(N'Home & Living'),(N'Sport & Outdoor'),(N'Beauty'),(N'Office'),(N'Kitchen');
INSERT INTO dbo.Carriers(CarrierName,StandardDeliveryDays) VALUES
 (N'EuroParcel',3),(N'Adriatic Express',2),(N'RegionalPost',5);
INSERT INTO dbo.Suppliers(CountryID,SupplierCode,SupplierName,DefaultLeadDays)
SELECT 1+((n-1)%3),CONCAT('SUP-',RIGHT(CONCAT('00',n),2)),
       CONCAT('Supplier ',RIGHT(CONCAT('00',n),2),' Distribution'),3+(n%9)
FROM (SELECT TOP(12) ROW_NUMBER() OVER(ORDER BY object_id) n FROM sys.all_objects) q;
INSERT INTO dbo.Products(SKU,CategoryID,ProductName,UnitPriceEUR,UnitCostEUR,ReorderPoint,ReorderQuantity)
SELECT CONCAT('SKU-',RIGHT(CONCAT('000',n),3)),1+((n-1)%6),
       CONCAT('Retail product ',RIGHT(CONCAT('000',n),3)),
       CONVERT(DECIMAL(12,2),15+(n*7)%180+0.99),
       CONVERT(DECIMAL(12,2),(15+(n*7)%180+0.99)*0.55),
       50+(n%5)*30,150+(n%4)*50
FROM (SELECT TOP(72) ROW_NUMBER() OVER(ORDER BY object_id) n FROM sys.all_objects) q;
INSERT INTO dbo.SupplierProducts(SupplierID,ProductID,ContractUnitCostEUR,MinimumOrderQty)
SELECT 1+((p.ProductID-1)%12),p.ProductID,p.UnitCostEUR,10
FROM dbo.Products p;
INSERT INTO dbo.SupplierProducts(SupplierID,ProductID,ContractUnitCostEUR,MinimumOrderQty)
SELECT 1+((p.ProductID+4)%12),p.ProductID,CONVERT(DECIMAL(12,2),p.UnitCostEUR*1.05),20
FROM dbo.Products p;
COMMIT TRAN;
GO
/* One address per fictional customer; identity sequences start at 1 in empty DB. */
;WITH N AS (
 SELECT TOP(5000) ROW_NUMBER() OVER(ORDER BY a.object_id,b.object_id) n
 FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Customers(HomeCountryID,FullName,Email,CreatedAt)
SELECT CONVERT(TINYINT,1+((n-1)%3)),CONCAT('Demo Customer ',n),
       CONCAT('demo.customer.',n,'@example.invalid'),DATEADD(DAY,-(n%1000),SYSUTCDATETIME())
FROM N;
INSERT INTO dbo.CustomerAddresses(CustomerID,CityID,StreetLine,PostalCode)
SELECT c.CustomerID,(CONVERT(INT,c.HomeCountryID)-1)*3+1+(c.CustomerID%3),
       CONCAT('Example Street ',c.CustomerID),CONCAT('10',RIGHT(CONCAT('000',c.CustomerID%1000),3))
FROM dbo.Customers c;
GO
/* Exactly 100k orders; 1,000 NEW / 2,000 SHIPPED / 97,000 DELIVERED.
   A synthetic holiday bump is included by placing every fifth historic order
   in the late-November/December 2025 window; near-current open orders in Oct 2026.
   Dates represent examples, not claims about a real business. */
;WITH N AS (
 SELECT TOP(100000) ROW_NUMBER() OVER(ORDER BY a.object_id,b.object_id) n
 FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.SalesOrders(OrderNumber,CustomerID,ShipAddressID,StoreID,SalesChannel,OrderStatus,OrderedAt)
SELECT CONCAT('HIST-',RIGHT(CONCAT('000000',n),6)),
       a.CustomerID,a.AddressID,
       CASE WHEN n%5=0 THEN 1+((n%6)) ELSE NULL END,
       CASE WHEN n%5=0 THEN 'STORE' ELSE 'ONLINE' END,
       CASE WHEN n>99000 THEN 'NEW' WHEN n>97000 THEN 'SHIPPED' ELSE 'DELIVERED' END,
       CASE WHEN n>97000
          THEN DATEADD(DAY,n%14,CONVERT(DATETIME2(0),'2026-10-18'))
          WHEN n%5=0
          THEN DATEADD(DAY,n%40,CONVERT(DATETIME2(0),'2025-11-18'))
          ELSE DATEADD(DAY,(n*37)%860,CONVERT(DATETIME2(0),'2024-01-01')) END
FROM N JOIN dbo.CustomerAddresses a ON a.CustomerID=1+((n*17)%5000);
GO
/* One item in 25% of orders, two items in 75%. Prices/costs snapshotted. */
INSERT INTO dbo.SalesOrderItems(OrderID,ProductID,Quantity,UnitPriceEUR,UnitCostEUR)
SELECT o.OrderID,p.ProductID,1+(o.OrderID%3),p.UnitPriceEUR,p.UnitCostEUR
FROM dbo.SalesOrders o JOIN dbo.Products p ON p.ProductID=1+((o.OrderID*13)%72);
INSERT INTO dbo.SalesOrderItems(OrderID,ProductID,Quantity,UnitPriceEUR,UnitCostEUR)
SELECT o.OrderID,p.ProductID,1+(o.OrderID%2),p.UnitPriceEUR,p.UnitCostEUR
FROM dbo.SalesOrders o JOIN dbo.Products p ON p.ProductID=1+((o.OrderID*13+17)%72)
WHERE o.OrderID%4<>0;
GO
/* One-warehouse historical fulfilled orders, allocated in customer's country. */
INSERT INTO dbo.OrderFulfillments(OrderID,WarehouseID,FulfillmentStatus,CreatedAt)
SELECT o.OrderID,(CONVERT(INT,c.HomeCountryID)-1)*2+1+CONVERT(INT,o.OrderID%2),
       CASE WHEN o.OrderStatus='DELIVERED' THEN 'DELIVERED' ELSE 'DISPATCHED' END,
       o.OrderedAt
FROM dbo.SalesOrders o JOIN dbo.Customers c ON c.CustomerID=o.CustomerID
WHERE o.OrderStatus IN ('DELIVERED','SHIPPED');
INSERT INTO dbo.FulfillmentItems(FulfillmentID,OrderItemID,Quantity)
SELECT f.FulfillmentID,oi.OrderItemID,oi.Quantity
FROM dbo.OrderFulfillments f JOIN dbo.SalesOrderItems oi ON oi.OrderID=f.OrderID;
INSERT INTO dbo.InventoryReservations(OrderItemID,WarehouseID,Quantity,ReservationStatus,CreatedAt)
SELECT fi.OrderItemID,f.WarehouseID,fi.Quantity,'CONSUMED',o.OrderedAt
FROM dbo.FulfillmentItems fi
JOIN dbo.OrderFulfillments f ON f.FulfillmentID=fi.FulfillmentID
JOIN dbo.SalesOrders o ON o.OrderID=f.OrderID;
INSERT INTO dbo.Shipments(FulfillmentID,CarrierID,TrackingNumber,ShipmentStatus,ShippedAt,ExpectedDeliveryAt,DeliveredAt)
SELECT f.FulfillmentID,1+CONVERT(INT,f.OrderID%3),CONCAT('HIST-TRACK-',f.OrderID),
       CASE WHEN o.OrderStatus='DELIVERED' THEN 'DELIVERED' ELSE 'IN_TRANSIT' END,
       DATEADD(DAY,1,o.OrderedAt),DATEADD(DAY,4,o.OrderedAt),
       CASE WHEN o.OrderStatus='DELIVERED' THEN DATEADD(DAY,CASE WHEN f.OrderID%5=0 THEN 6 ELSE 3 END,o.OrderedAt) ELSE NULL END
FROM dbo.OrderFulfillments f JOIN dbo.SalesOrders o ON o.OrderID=f.OrderID;
GO
/* 560+ fictional received returns, some restocked and some discarded. */
INSERT INTO dbo.ReturnRequests(OrderID,ReturnStatus,RequestedAt,ProcessedAt)
SELECT o.OrderID,'RECEIVED',DATEADD(DAY,8,o.OrderedAt),DATEADD(DAY,10,o.OrderedAt)
FROM dbo.SalesOrders o WHERE o.OrderStatus='DELIVERED' AND o.OrderID%173=0;
INSERT INTO dbo.ReturnItems(ReturnID,OrderItemID,Quantity,Disposition)
SELECT r.ReturnID,oi.OrderItemID,1,
       CASE WHEN r.ReturnID%2=0 THEN 'RESTOCK' ELSE 'SCRAP' END
FROM dbo.ReturnRequests r CROSS APPLY (
 SELECT TOP(1) OrderItemID FROM dbo.SalesOrderItems WHERE OrderID=r.OrderID ORDER BY OrderItemID
) oi;
GO
/* Current warehouse snapshots; the opening ledger entry is calculated to
   reconcile against every past SALE and RESTOCK RETURN movement. */
INSERT INTO dbo.Inventory(WarehouseID,ProductID,QuantityOnHand,QuantityReserved)
SELECT w.WarehouseID,p.ProductID,
       CASE WHEN p.ProductID%13=0 THEN 8+(w.WarehouseID%4)
            ELSE 180+((p.ProductID*19+w.WarehouseID*23)%640) END,0
FROM dbo.Warehouses w CROSS JOIN dbo.Products p;
GO
/* Ensure opening + sales + returns = ending on-hand for each SKU / warehouse. */
;WITH Sold AS (
 SELECT f.WarehouseID,oi.ProductID,SUM(CONVERT(BIGINT,fi.Quantity)) SoldQty
 FROM dbo.FulfillmentItems fi JOIN dbo.OrderFulfillments f ON f.FulfillmentID=fi.FulfillmentID
 JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=fi.OrderItemID
 GROUP BY f.WarehouseID,oi.ProductID
), Restocked AS (
 SELECT f.WarehouseID,oi.ProductID,SUM(CONVERT(BIGINT,ri.Quantity)) ReturnedQty
 FROM dbo.ReturnItems ri JOIN dbo.ReturnRequests rr ON rr.ReturnID=ri.ReturnID
 JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=ri.OrderItemID
 JOIN dbo.OrderFulfillments f ON f.OrderID=oi.OrderID
 WHERE rr.ReturnStatus='RECEIVED' AND ri.Disposition='RESTOCK'
 GROUP BY f.WarehouseID,oi.ProductID
)
INSERT INTO dbo.InventoryMovements(WarehouseID,ProductID,QuantityDelta,MovementType,ReferenceType,OccurredAt)
SELECT i.WarehouseID,i.ProductID,
       CONVERT(INT,i.QuantityOnHand+COALESCE(s.SoldQty,0)-COALESCE(r.ReturnedQty,0)),
       'OPENING','Dataset',CONVERT(DATETIME2(0),'2023-12-31')
FROM dbo.Inventory i
LEFT JOIN Sold s ON s.WarehouseID=i.WarehouseID AND s.ProductID=i.ProductID
LEFT JOIN Restocked r ON r.WarehouseID=i.WarehouseID AND r.ProductID=i.ProductID;
INSERT INTO dbo.InventoryMovements(WarehouseID,ProductID,QuantityDelta,MovementType,ReferenceType,ReferenceID,OccurredAt)
SELECT f.WarehouseID,oi.ProductID,-fi.Quantity,'SALE','Fulfillment',f.FulfillmentID,s.ShippedAt
FROM dbo.FulfillmentItems fi JOIN dbo.OrderFulfillments f ON f.FulfillmentID=fi.FulfillmentID
JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=fi.OrderItemID
JOIN dbo.Shipments s ON s.FulfillmentID=f.FulfillmentID;
INSERT INTO dbo.InventoryMovements(WarehouseID,ProductID,QuantityDelta,MovementType,ReferenceType,ReferenceID,OccurredAt)
SELECT f.WarehouseID,oi.ProductID,ri.Quantity,'RETURN','ReturnRequest',r.ReturnID,r.ProcessedAt
FROM dbo.ReturnItems ri JOIN dbo.ReturnRequests r ON r.ReturnID=ri.ReturnID
JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=ri.OrderItemID
JOIN dbo.OrderFulfillments f ON f.OrderID=oi.OrderID
WHERE ri.Disposition='RESTOCK' AND r.ReturnStatus='RECEIVED';
GO
/* Smaller purchasing dataset, balanced between timely and overdue orders. */
INSERT INTO dbo.PurchaseOrders(SupplierID,WarehouseID,PurchaseOrderNumber,PurchaseStatus,OrderedAt,ExpectedAt)
SELECT s.SupplierID,1+((s.SupplierID-1)%6),CONCAT('PO-DEMO-',RIGHT(CONCAT('00',s.SupplierID),2)),
       CASE WHEN s.SupplierID<=2 THEN 'DRAFT' ELSE 'APPROVED' END,
       DATEADD(DAY,-10,SYSUTCDATETIME()),
       CASE WHEN s.SupplierID%3=0 THEN DATEADD(DAY,-2,SYSUTCDATETIME())
            ELSE DATEADD(DAY,3,SYSUTCDATETIME()) END
FROM dbo.Suppliers s;
INSERT INTO dbo.PurchaseOrderItems(PurchaseOrderID,ProductID,QuantityOrdered,UnitCostEUR)
SELECT po.PurchaseOrderID,sp.ProductID,100+CONVERT(INT,po.PurchaseOrderID%5)*25,sp.ContractUnitCostEUR
FROM dbo.PurchaseOrders po CROSS APPLY(
 SELECT TOP(2) ProductID,ContractUnitCostEUR FROM dbo.SupplierProducts
 WHERE SupplierID=po.SupplierID ORDER BY ProductID
) sp;
GO
SELECT (SELECT COUNT(*) FROM dbo.SalesOrders) Orders,
       (SELECT COUNT(*) FROM dbo.SalesOrderItems) OrderLines,
       (SELECT COUNT(*) FROM dbo.Customers) Customers,
       (SELECT COUNT(*) FROM dbo.InventoryMovements) LedgerEvents,
       (SELECT COUNT(*) FROM dbo.Shipments) Shipments;
GO
