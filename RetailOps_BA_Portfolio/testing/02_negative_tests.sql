/* RetailOps v1.8 | NEGATIVE TESTS | Run on demo RetailOpsDB ONLY.
   N01/N03 pass JSON variables (NOT CONCAT function calls) to EXEC.
   Expected failure codes are caught; PASS is printed only after assertions.
   Test-created orders are cancelled, not deleted. Do not run 00-06 again. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
DECLARE @C INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
DECLARE @A INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@C);
DECLARE @P INT=(SELECT TOP(1) ProductID FROM dbo.Products ORDER BY ProductID);
DECLARE @O BIGINT,@Rejected BIT=0;
DECLARE @J NVARCHAR(MAX);
SET @J = CONCAT(N'[{"ProductID":',@P,N',"Quantity":9999999}]');
EXEC dbo.usp_CreateOrder @CustomerID=@C,@ShipAddressID=@A,@SalesChannel='ONLINE',
     @ItemsJson=@J,@OrderID=@O OUTPUT;
BEGIN TRY
    EXEC dbo.usp_AllocateOrder @OrderID=@O;
END TRY BEGIN CATCH
    IF ERROR_NUMBER()=51102 SET @Rejected=1;
    ELSE THROW;
END CATCH;
IF @Rejected<>1 THROW 54000,'Insufficient-stock order was unexpectedly accepted.',1;
IF EXISTS(SELECT 1 FROM dbo.InventoryReservations r JOIN dbo.SalesOrderItems i ON i.OrderItemID=r.OrderItemID WHERE i.OrderID=@O)
    THROW 54001,'Failed allocation left a reservation.',1;
IF (SELECT OrderStatus FROM dbo.SalesOrders WHERE OrderID=@O)<>'NEW'
    THROW 54002,'Failed allocation modified order status.',1;
EXEC dbo.usp_CancelOrder @OrderID=@O;
PRINT 'PASS N01 insufficient stock rolls back cleanly';
GO
DECLARE @PI BIGINT=(SELECT TOP(1) pi.PurchaseOrderItemID FROM dbo.PurchaseOrderItems pi JOIN dbo.PurchaseOrders po ON po.PurchaseOrderID=pi.PurchaseOrderID WHERE po.PurchaseStatus IN ('APPROVED','PARTIAL') ORDER BY pi.PurchaseOrderItemID);
DECLARE @Rejected2 BIT=0;
BEGIN TRY
 EXEC dbo.usp_ReceivePurchaseOrderItem @PurchaseOrderItemID=@PI,@Quantity=2147483647,
     @ReceiptReference='TEST-OVERRECEIPT';
END TRY BEGIN CATCH
 IF ERROR_NUMBER()=51502 SET @Rejected2=1; ELSE THROW;
END CATCH;
IF @Rejected2<>1 THROW 54003,'Excess PO receipt was unexpectedly accepted.',1;
PRINT 'PASS N02 over-receipt rejected';
GO

-- N03: an idempotency key must not silently accept a different order payload.
DECLARE @C3 INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
DECLARE @A3 INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@C3);
DECLARE @P3 INT=(SELECT TOP(1) ProductID FROM dbo.Products ORDER BY ProductID);
DECLARE @K3 VARCHAR(80)=CONCAT('TEST-IDEMP-CONFLICT-',CONVERT(VARCHAR(36),NEWID()));
DECLARE @O3 BIGINT,@Attempt3 BIGINT,@Rejected3 BIT=0;
DECLARE @J31 NVARCHAR(MAX);
SET @J31 = CONCAT(N'[{"ProductID":',@P3,N',"Quantity":1}]');
DECLARE @J32 NVARCHAR(MAX);
SET @J32 = CONCAT(N'[{"ProductID":',@P3,N',"Quantity":2}]');
EXEC dbo.usp_CreateOrder @CustomerID=@C3,@ShipAddressID=@A3,@SalesChannel='ONLINE',
    @ItemsJson=@J31,
    @ExternalRequestKey=@K3,@OrderID=@O3 OUTPUT;
BEGIN TRY
    EXEC dbo.usp_CreateOrder @CustomerID=@C3,@ShipAddressID=@A3,@SalesChannel='ONLINE',
        @ItemsJson=@J32,
        @ExternalRequestKey=@K3,@OrderID=@Attempt3 OUTPUT;
END TRY BEGIN CATCH
    IF ERROR_NUMBER()=51009 SET @Rejected3=1; ELSE THROW;
END CATCH;
IF @Rejected3<>1 THROW 54004,'Conflicting idempotency request was accepted.',1;
IF (SELECT COUNT(*) FROM dbo.SalesOrders WHERE ExternalRequestKey=@K3)<>1
    THROW 54005,'Conflicting idempotency request created a duplicate order.',1;
IF (SELECT SUM(Quantity) FROM dbo.SalesOrderItems WHERE OrderID=@O3)<>1
    THROW 54006,'Conflicting idempotency request modified existing quantity.',1;
EXEC dbo.usp_CancelOrder @OrderID=@O3;
PRINT 'PASS N03 idempotency payload conflict rejected';
GO
