/* RetailOps | 06 | Controlled example of complete user stories.
   Run ONCE after seed + views. Rerun protection through external request key. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
IF EXISTS(SELECT 1 FROM dbo.SalesOrders WHERE ExternalRequestKey='PORTFOLIO-DEMO-001')
BEGIN
    PRINT 'Demo already completed; skipped.';
END
ELSE
BEGIN
    DECLARE @CustomerID INT=(SELECT TOP(1) CustomerID FROM dbo.Customers ORDER BY CustomerID);
    DECLARE @AddressID INT=(SELECT TOP(1) AddressID FROM dbo.CustomerAddresses WHERE CustomerID=@CustomerID);
    DECLARE @Product1 INT=(SELECT TOP(1) ProductID FROM dbo.Products WHERE IsActive=1 ORDER BY ProductID);
    DECLARE @Product2 INT=(SELECT TOP(1) ProductID FROM dbo.Products WHERE IsActive=1 AND ProductID>@Product1 ORDER BY ProductID);
    DECLARE @Order BIGINT, @Shipment BIGINT, @Fulfillment BIGINT, @ReturnID BIGINT, @Item BIGINT;
    DECLARE @Items NVARCHAR(MAX)=CONCAT('[{"ProductID":',@Product1,',"Quantity":2},{"ProductID":',@Product2,',"Quantity":1}]');
    EXEC dbo.usp_CreateOrder @CustomerID=@CustomerID,@ShipAddressID=@AddressID,@SalesChannel='ONLINE',
         @ItemsJson=@Items,@ExternalRequestKey='PORTFOLIO-DEMO-001',@OrderID=@Order OUTPUT;
    EXEC dbo.usp_AllocateOrder @OrderID=@Order;
    /* Each warehouse creates its own fulfillment; demo usually selects one. */
    DECLARE @FList TABLE(FulfillmentID BIGINT PRIMARY KEY);
    INSERT INTO @FList SELECT FulfillmentID FROM dbo.OrderFulfillments WHERE OrderID=@Order;
    DECLARE FCursor CURSOR LOCAL FAST_FORWARD FOR SELECT FulfillmentID FROM @FList;
    OPEN FCursor; FETCH NEXT FROM FCursor INTO @Fulfillment;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC dbo.usp_DispatchFulfillment @FulfillmentID=@Fulfillment,@CarrierID=1,@ShipmentID=@Shipment OUTPUT;
        EXEC dbo.usp_MarkShipmentDelivered @ShipmentID=@Shipment;
        FETCH NEXT FROM FCursor INTO @Fulfillment;
    END;
    CLOSE FCursor; DEALLOCATE FCursor;
    INSERT INTO dbo.ReturnRequests(OrderID,ReturnStatus) VALUES(@Order,'APPROVED');
    SET @ReturnID=SCOPE_IDENTITY();
    SELECT TOP(1) @Item=OrderItemID FROM dbo.SalesOrderItems WHERE OrderID=@Order ORDER BY OrderItemID;
    INSERT INTO dbo.ReturnItems(ReturnID,OrderItemID,Quantity,Disposition) VALUES(@ReturnID,@Item,1,'RESTOCK');
    DECLARE @ReturnsWarehouse INT=(SELECT TOP(1) WarehouseID FROM dbo.OrderFulfillments WHERE OrderID=@Order ORDER BY WarehouseID);
    EXEC dbo.usp_ReceiveReturn @ReturnID=@ReturnID,@ProcessingWarehouseID=@ReturnsWarehouse;
    PRINT CONCAT('Demo delivered order and processed restock return; orderId=',@Order);
END;
GO
/* Purchasing example (also idempotent: references are globally unique). */
DECLARE @ItemID BIGINT,@N INT=0,@Reference VARCHAR(80);
DECLARE POCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TOP(8) pi.PurchaseOrderItemID FROM dbo.PurchaseOrderItems pi
    JOIN dbo.PurchaseOrders po ON po.PurchaseOrderID=pi.PurchaseOrderID
    WHERE po.PurchaseStatus IN ('APPROVED','PARTIAL')
    ORDER BY pi.PurchaseOrderItemID;
OPEN POCursor;
FETCH NEXT FROM POCursor INTO @ItemID;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Reference=CONCAT('INITIAL-DEMO-',@ItemID);
    IF NOT EXISTS(SELECT 1 FROM dbo.GoodsReceipts WHERE ReceiptReference=@Reference)
        EXEC dbo.usp_ReceivePurchaseOrderItem @PurchaseOrderItemID=@ItemID,@Quantity=25,@ReceiptReference=@Reference;
    FETCH NEXT FROM POCursor INTO @ItemID;
END;
CLOSE POCursor; DEALLOCATE POCursor;
GO
SELECT TOP(10) OrderID,OrderStatus,OrderNumber FROM dbo.SalesOrders ORDER BY OrderID DESC;
SELECT TOP(10) * FROM dbo.vw_ProcurementPerformance WHERE ReceivedQty>0;
GO
