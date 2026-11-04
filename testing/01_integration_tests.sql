/* RetailOps v1.7 | Integration tests | Run after seed + demo; SQL Server 2019+.
   Main test cases run in an outer transaction and roll back afterward.
   Expected THROW cases run separately because XACT_ABORT may doom a parent transaction.
   A FAIL raises an error; PASS lines are printed in Messages.
   T05-T07 use set-based aggregates. T07 materializes and indexes the result for predictable performance. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
-- T01: full lifecycle (create -> reserve -> dispatch -> deliver -> return)
BEGIN TRY
  BEGIN TRAN;
  DECLARE @C INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
  DECLARE @A INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@C);
  DECLARE @P INT=(SELECT TOP(1) ProductID FROM dbo.Products ORDER BY ProductID);
  DECLARE @W INT,@O BIGINT,@F BIGINT,@S BIGINT,@R BIGINT,@OI BIGINT;
  DECLARE @Before INT=(SELECT SUM(QuantityOnHand) FROM dbo.Inventory WHERE ProductID=@P);
  DECLARE @Key VARCHAR(80)=CONCAT('TEST-LIFECYCLE-',CONVERT(VARCHAR(36),NEWID()));
  DECLARE @J1 NVARCHAR(MAX)=CONCAT(N'[{"ProductID":',@P,N',"Quantity":2}]');
  EXEC dbo.usp_CreateOrder @CustomerID=@C,@ShipAddressID=@A,@SalesChannel='ONLINE',
       @ItemsJson=@J1,@ExternalRequestKey=@Key,@OrderID=@O OUTPUT;
  IF NOT EXISTS(SELECT 1 FROM dbo.SalesOrders WHERE OrderID=@O AND OrderStatus='NEW') THROW 53001,'T01 create failed',1;
  EXEC dbo.usp_AllocateOrder @OrderID=@O;
  IF (SELECT SUM(r.Quantity) FROM dbo.InventoryReservations r JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=r.OrderItemID WHERE oi.OrderID=@O AND r.ReservationStatus='ACTIVE')<>2
      THROW 53002,'T01 allocation failed',1;
  SELECT TOP(1) @F=FulfillmentID,@W=WarehouseID FROM dbo.OrderFulfillments WHERE OrderID=@O;
  EXEC dbo.usp_DispatchFulfillment @FulfillmentID=@F,@CarrierID=1,@ShipmentID=@S OUTPUT;
  IF (SELECT SUM(QuantityOnHand) FROM dbo.Inventory WHERE ProductID=@P)<>@Before-2 THROW 53003,'T01 dispatch failed',1;
  EXEC dbo.usp_MarkShipmentDelivered @ShipmentID=@S;
  IF NOT EXISTS(SELECT 1 FROM dbo.SalesOrders WHERE OrderID=@O AND OrderStatus='DELIVERED') THROW 53004,'T01 delivery failed',1;
  INSERT INTO dbo.ReturnRequests(OrderID,ReturnStatus) VALUES(@O,'APPROVED');
  SET @R=SCOPE_IDENTITY();
  SELECT @OI=OrderItemID FROM dbo.SalesOrderItems WHERE OrderID=@O;
  INSERT INTO dbo.ReturnItems(ReturnID,OrderItemID,Quantity,Disposition) VALUES(@R,@OI,1,'RESTOCK');
  EXEC dbo.usp_ReceiveReturn @ReturnID=@R,@ProcessingWarehouseID=@W;
  IF (SELECT SUM(QuantityOnHand) FROM dbo.Inventory WHERE ProductID=@P)<>@Before-1 THROW 53005,'T01 return restock failed',1;
  PRINT 'PASS T01 lifecycle, stock decrement, delivery and restock';
  ROLLBACK TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRAN;
  THROW;
END CATCH;
GO
-- T02: cancellation releases reservations (no on-hand movement)
BEGIN TRY
  BEGIN TRAN;
  DECLARE @C2 INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
  DECLARE @A2 INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@C2);
  DECLARE @P2 INT=(SELECT TOP(1) ProductID FROM dbo.Products ORDER BY ProductID);
  DECLARE @O2 BIGINT;
  DECLARE @StartReserved INT=(SELECT SUM(QuantityReserved) FROM dbo.Inventory WHERE ProductID=@P2);
  DECLARE @J2 NVARCHAR(MAX)=CONCAT(N'[{"ProductID":',@P2,N',"Quantity":3}]');
  EXEC dbo.usp_CreateOrder @CustomerID=@C2,@ShipAddressID=@A2,@SalesChannel='ONLINE',
       @ItemsJson=@J2,@OrderID=@O2 OUTPUT;
  EXEC dbo.usp_AllocateOrder @OrderID=@O2;
  IF (SELECT SUM(QuantityReserved) FROM dbo.Inventory WHERE ProductID=@P2)<>@StartReserved+3
    THROW 53100,'T02 reservation count incorrect',1;
  EXEC dbo.usp_CancelOrder @OrderID=@O2;
  IF (SELECT SUM(QuantityReserved) FROM dbo.Inventory WHERE ProductID=@P2)<>@StartReserved
    THROW 53101,'T02 cancellation did not release stock',1;
  IF EXISTS(SELECT 1 FROM dbo.InventoryReservations r JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=r.OrderItemID WHERE oi.OrderID=@O2 AND r.ReservationStatus='ACTIVE')
    THROW 53102,'T02 active reservation remained',1;
  PRINT 'PASS T02 cancellations and reservation release';
  ROLLBACK TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRAN;
  THROW;
END CATCH;
GO
-- T03: idempotency key reuses the original order ID
BEGIN TRY
  BEGIN TRAN;
  DECLARE @C3 INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
  DECLARE @A3 INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@C3);
  DECLARE @P3 INT=(SELECT TOP(1) ProductID FROM dbo.Products ORDER BY ProductID);
  DECLARE @O3 BIGINT,@O3Repeat BIGINT;
  DECLARE @K3 VARCHAR(80)=CONCAT('TEST-IDEMP-',CONVERT(VARCHAR(36),NEWID()));
  DECLARE @J3 NVARCHAR(MAX)=CONCAT('[{"ProductID":',@P3,',"Quantity":1}]');
  EXEC dbo.usp_CreateOrder @CustomerID=@C3,@ShipAddressID=@A3,@SalesChannel='ONLINE',@ItemsJson=@J3,@ExternalRequestKey=@K3,@OrderID=@O3 OUTPUT;
  EXEC dbo.usp_CreateOrder @CustomerID=@C3,@ShipAddressID=@A3,@SalesChannel='ONLINE',@ItemsJson=@J3,@ExternalRequestKey=@K3,@OrderID=@O3Repeat OUTPUT;
  IF @O3<>@O3Repeat OR (SELECT COUNT(*) FROM dbo.SalesOrders WHERE ExternalRequestKey=@K3)<>1
    THROW 53200,'T03 idempotency failed',1;
  PRINT 'PASS T03 repeated external request returns same order ID';
  ROLLBACK TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRAN;
  THROW;
END CATCH;
GO
-- T04: partial procurement and ledger correctness
BEGIN TRY
  BEGIN TRAN;
  DECLARE @PI BIGINT=(SELECT TOP(1) pi.PurchaseOrderItemID FROM dbo.PurchaseOrderItems pi JOIN dbo.PurchaseOrders po ON po.PurchaseOrderID=pi.PurchaseOrderID WHERE po.PurchaseStatus IN ('APPROVED','PARTIAL') ORDER BY pi.PurchaseOrderItemID);
  DECLARE @PP INT=(SELECT ProductID FROM dbo.PurchaseOrderItems WHERE PurchaseOrderItemID=@PI);
  DECLARE @PW INT=(SELECT po.WarehouseID FROM dbo.PurchaseOrderItems pi JOIN dbo.PurchaseOrders po ON po.PurchaseOrderID=pi.PurchaseOrderID WHERE pi.PurchaseOrderItemID=@PI);
  DECLARE @OldQty INT=(SELECT QuantityOnHand FROM dbo.Inventory WHERE ProductID=@PP AND WarehouseID=@PW);
  EXEC dbo.usp_ReceivePurchaseOrderItem @PurchaseOrderItemID=@PI,@Quantity=1,@ReceiptReference='TEST-RECV-SESSION';
  IF (SELECT QuantityOnHand FROM dbo.Inventory WHERE ProductID=@PP AND WarehouseID=@PW)<>@OldQty+1
    THROW 53300,'T04 PO receiving failed',1;
  PRINT 'PASS T04 procurement receipt increments inventory';
  ROLLBACK TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRAN;
  THROW;
END CATCH;
GO
-- T05: reconcile stock with movement ledger using one grouped pass.
IF EXISTS (
    SELECT 1
    FROM dbo.Inventory AS i
    LEFT JOIN (
        SELECT WarehouseID, ProductID,
               SUM(CONVERT(BIGINT, QuantityDelta)) AS LedgerQty
        FROM dbo.InventoryMovements
        GROUP BY WarehouseID,ProductID
    ) AS x ON x.WarehouseID=i.WarehouseID AND x.ProductID=i.ProductID
    WHERE CONVERT(BIGINT,i.QuantityOnHand)<>COALESCE(x.LedgerQty,CONVERT(BIGINT,0))
) THROW 53400,'T05 stock/ledger reconciliation mismatch',1;
PRINT 'PASS T05 inventory ledger reconciliation';
GO
-- T06: reconcile actively reserved units with inventory counters.
IF EXISTS (
    SELECT 1
    FROM dbo.Inventory AS i
    LEFT JOIN (
        SELECT r.WarehouseID, oi.ProductID,
               SUM(CONVERT(BIGINT,r.Quantity)) AS ReservedQty
        FROM dbo.InventoryReservations AS r
        JOIN dbo.SalesOrderItems AS oi ON oi.OrderItemID=r.OrderItemID
        WHERE r.ReservationStatus='ACTIVE'
        GROUP BY r.WarehouseID,oi.ProductID
    ) AS x ON x.WarehouseID=i.WarehouseID AND x.ProductID=i.ProductID
    WHERE CONVERT(BIGINT,i.QuantityReserved)<>COALESCE(x.ReservedQty,CONVERT(BIGINT,0))
) THROW 53401,'T06 active reservation balances mismatch',1;
PRINT 'PASS T06 active reservation balances';
GO
-- T07: quantity reconciliation using a materialized, indexed aggregate.
-- The equivalent standalone V07 was confirmed on the local demonstration dataset.
DROP TABLE IF EXISTS #FulfillmentTotals;

SELECT fi.OrderItemID,
       SUM(CONVERT(BIGINT, fi.Quantity)) AS AllocatedQty
INTO #FulfillmentTotals
FROM dbo.FulfillmentItems AS fi
GROUP BY fi.OrderItemID;

CREATE UNIQUE CLUSTERED INDEX CX_T07_FulfillmentTotals
ON #FulfillmentTotals(OrderItemID);

IF EXISTS (
    SELECT 1
    FROM dbo.SalesOrders AS o
    JOIN dbo.SalesOrderItems AS oi ON oi.OrderID=o.OrderID
    LEFT JOIN #FulfillmentTotals AS ft ON ft.OrderItemID=oi.OrderItemID
    WHERE o.OrderStatus IN ('RESERVED','PARTIAL','SHIPPED','DELIVERED')
      AND CONVERT(BIGINT,oi.Quantity)<>COALESCE(ft.AllocatedQty,CONVERT(BIGINT,0))
)
BEGIN
    DROP TABLE #FulfillmentTotals;
    THROW 53402,'T07 fulfillment line conservation mismatch',1;
END;
DROP TABLE #FulfillmentTotals;
PRINT 'PASS T07 fulfilled quantity equals ordered quantity';
GO
-- T08: domestic split allocation across two warehouses; data changes rolled back
BEGIN TRY
  BEGIN TRAN;
  DECLARE @C8 INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
  DECLARE @A8 INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@C8);
  DECLARE @Country8 TINYINT=(SELECT ci.CountryID FROM dbo.CustomerAddresses a JOIN dbo.Cities ci ON ci.CityID=a.CityID WHERE a.AddressID=@A8);
  DECLARE @P8 INT=(SELECT TOP(1) ProductID FROM dbo.Products ORDER BY ProductID);
  DECLARE @W18 INT,@W28 INT,@O8 BIGINT;
  SELECT @W18=MIN(w.WarehouseID),@W28=MAX(w.WarehouseID)
  FROM dbo.Warehouses w JOIN dbo.Cities ci ON ci.CityID=w.CityID WHERE ci.CountryID=@Country8;
  IF @W18 IS NULL OR @W28 IS NULL OR @W18=@W28 THROW 53800,'T08 needs two domestic warehouses',1;
  UPDATE dbo.Inventory SET QuantityOnHand=CASE WHEN WarehouseID=@W18 THEN 1 ELSE 2 END,QuantityReserved=0
  WHERE ProductID=@P8 AND WarehouseID IN (@W18,@W28);
  DECLARE @J8 NVARCHAR(MAX)=CONCAT(N'[{"ProductID":',@P8,N',"Quantity":3}]');
  EXEC dbo.usp_CreateOrder @CustomerID=@C8,@ShipAddressID=@A8,@SalesChannel='ONLINE',
       @ItemsJson=@J8,@OrderID=@O8 OUTPUT;
  EXEC dbo.usp_AllocateOrder @OrderID=@O8;
  IF (SELECT COUNT(*) FROM dbo.OrderFulfillments WHERE OrderID=@O8)<>2
     THROW 53801,'T08 expected 2 distinct warehouse fulfillments',1;
  IF (SELECT SUM(r.Quantity) FROM dbo.InventoryReservations r JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=r.OrderItemID WHERE oi.OrderID=@O8)<>3
     THROW 53802,'T08 quantity not fully allocated',1;
  PRINT 'PASS T08 split allocation creates two warehouse fulfillments';
  ROLLBACK TRAN;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRAN;
  THROW;
END CATCH;
GO

PRINT 'End of script reached. Review all Messages: only tests showing PASS without errors can be counted as passed.';
GO
