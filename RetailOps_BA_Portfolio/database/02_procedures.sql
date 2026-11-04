/* RetailOps | 02 | Transactional business operations
   Read committed + targeted update/range locks; XACT_ABORT and TRY/CATCH.
   All business writes should go through these procedures, not ad-hoc UPDATEs. */
USE RetailOpsDB;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateOrder
    @CustomerID INT,
    @ShipAddressID INT,
    @SalesChannel VARCHAR(10),
    @ItemsJson NVARCHAR(MAX),
    @StoreID INT = NULL,
    @ExternalRequestKey VARCHAR(80) = NULL,
    @OrderID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @AppLockResult INT, @ExistingOrderID BIGINT, @AppLockResource NVARCHAR(255);
    SET @OrderID=NULL;
    BEGIN TRY
        BEGIN TRAN;
        IF @ExternalRequestKey IS NOT NULL
        BEGIN
            SET @AppLockResource = CONCAT(N'RetailOps.Order.', @ExternalRequestKey);
            EXEC @AppLockResult = sys.sp_getapplock
                @Resource = @AppLockResource,
                @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
            IF @AppLockResult < 0 THROW 51000, 'Could not acquire idempotency lock.', 1;
            SELECT @ExistingOrderID = OrderID FROM dbo.SalesOrders WITH (UPDLOCK,HOLDLOCK)
            WHERE ExternalRequestKey=@ExternalRequestKey;
            /* Compare with the complete normalized request before accepting a retry. */
        END;
        IF @SalesChannel NOT IN ('ONLINE','STORE') OR @SalesChannel IS NULL
            THROW 51001, 'Invalid sales channel.', 1;
        IF @SalesChannel='STORE' AND @StoreID IS NULL
            THROW 51002, 'Store orders require a StoreID.', 1;
        IF @StoreID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.Stores WHERE StoreID=@StoreID AND IsActive=1)
            THROW 51003, 'Store is invalid or inactive.', 1;
        IF NOT EXISTS(SELECT 1 FROM dbo.CustomerAddresses WHERE AddressID=@ShipAddressID AND CustomerID=@CustomerID)
            THROW 51004, 'Shipping address does not belong to customer.', 1;
        IF @ItemsJson IS NULL OR ISJSON(@ItemsJson)<>1 OR LEFT(LTRIM(@ItemsJson),1)<>N'['
            THROW 51005, 'ItemsJson must be a JSON array.', 1;
        DECLARE @Parsed TABLE(ProductID INT NULL, Quantity INT NULL);
        INSERT INTO @Parsed(ProductID,Quantity)
        SELECT ProductID, Quantity
        FROM OPENJSON(@ItemsJson)
        WITH (ProductID INT '$.ProductID', Quantity INT '$.Quantity');
        IF NOT EXISTS(SELECT 1 FROM @Parsed) OR EXISTS(SELECT 1 FROM @Parsed WHERE ProductID IS NULL OR Quantity IS NULL OR Quantity<=0)
            THROW 51006, 'Each line requires ProductID and positive Quantity.', 1;
        IF EXISTS(SELECT 1 FROM @Parsed x LEFT JOIN dbo.Products p ON p.ProductID=x.ProductID AND p.IsActive=1 WHERE p.ProductID IS NULL)
            THROW 51007, 'Unknown or inactive product.', 1;
        IF EXISTS(SELECT ProductID FROM @Parsed GROUP BY ProductID HAVING SUM(CONVERT(BIGINT,Quantity)) > 2147483647)
            THROW 51008, 'Item quantity overflow.', 1;
        /* Idempotent replay is allowed only if all request data matches.
           EXCEPT compares normalized product/quantity sets in both directions. */
        IF @ExistingOrderID IS NOT NULL
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM dbo.SalesOrders o
                WHERE o.OrderID=@ExistingOrderID
                  AND o.CustomerID=@CustomerID AND o.ShipAddressID=@ShipAddressID
                  AND o.SalesChannel=@SalesChannel
                  AND ISNULL(o.StoreID,-1)=ISNULL(@StoreID,-1)
            ) OR EXISTS (
                SELECT ProductID,SUM(CONVERT(BIGINT,Quantity)) AS Qty
                FROM @Parsed GROUP BY ProductID
                EXCEPT
                SELECT ProductID,CONVERT(BIGINT,Quantity)
                FROM dbo.SalesOrderItems WHERE OrderID=@ExistingOrderID
            ) OR EXISTS (
                SELECT ProductID,CONVERT(BIGINT,Quantity)
                FROM dbo.SalesOrderItems WHERE OrderID=@ExistingOrderID
                EXCEPT
                SELECT ProductID,SUM(CONVERT(BIGINT,Quantity)) AS Qty
                FROM @Parsed GROUP BY ProductID
            )
                THROW 51009, 'Idempotency key already belongs to a different order request.', 1;
            SET @OrderID=@ExistingOrderID;
            COMMIT TRAN;
            RETURN;
        END;
        INSERT INTO dbo.SalesOrders(OrderNumber,ExternalRequestKey,CustomerID,ShipAddressID,StoreID,SalesChannel,OrderStatus)
        VALUES(CONCAT('P-',CONVERT(VARCHAR(36),NEWID())),@ExternalRequestKey,@CustomerID,@ShipAddressID,@StoreID,@SalesChannel,'NEW');
        SET @OrderID=SCOPE_IDENTITY();
        UPDATE dbo.SalesOrders SET OrderNumber=CONCAT('RO-',RIGHT(CONCAT('000000000000',CONVERT(VARCHAR(20),@OrderID)),12)) WHERE OrderID=@OrderID;
        INSERT INTO dbo.SalesOrderItems(OrderID,ProductID,Quantity,UnitPriceEUR,UnitCostEUR)
        SELECT @OrderID, p.ProductID, CONVERT(INT,SUM(CONVERT(BIGINT,x.Quantity))), p.UnitPriceEUR, p.UnitCostEUR
        FROM @Parsed x JOIN dbo.Products p ON p.ProductID=x.ProductID
        GROUP BY p.ProductID,p.UnitPriceEUR,p.UnitCostEUR;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails)
        VALUES('ORDER_CREATED','SalesOrder',@OrderID,CONCAT('{"channel":"',@SalesChannel,'"}'));
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_AllocateOrder
    @OrderID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @CurrentStatus VARCHAR(12), @DestinationCountry TINYINT;
    DECLARE @OrderItemID BIGINT, @ProductID INT, @Quantity INT, @Remaining INT;
    DECLARE @WarehouseID INT, @Available INT, @Take INT, @FulfillmentID BIGINT;
    BEGIN TRY
        BEGIN TRAN;
        SELECT @CurrentStatus=o.OrderStatus, @DestinationCountry=ci.CountryID
        FROM dbo.SalesOrders o WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.CustomerAddresses a ON a.AddressID=o.ShipAddressID
        JOIN dbo.Cities ci ON ci.CityID=a.CityID
        WHERE o.OrderID=@OrderID;
        IF @CurrentStatus IS NULL THROW 51100, 'Order not found.', 1;
        IF @CurrentStatus<>'NEW' THROW 51101, 'Only NEW orders can be allocated.', 1;
        DECLARE ItemCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT OrderItemID,ProductID,Quantity FROM dbo.SalesOrderItems
            WHERE OrderID=@OrderID ORDER BY ProductID,OrderItemID;
        OPEN ItemCursor;
        FETCH NEXT FROM ItemCursor INTO @OrderItemID,@ProductID,@Quantity;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Remaining=@Quantity;
            WHILE @Remaining>0
            BEGIN
                SET @WarehouseID=NULL;
                SET @Available=NULL;
                SELECT TOP(1) @WarehouseID=i.WarehouseID,
                              @Available=i.QuantityOnHand-i.QuantityReserved
                FROM dbo.Inventory i WITH (UPDLOCK,HOLDLOCK)
                JOIN dbo.Warehouses w ON w.WarehouseID=i.WarehouseID AND w.IsActive=1
                JOIN dbo.Cities ci ON ci.CityID=w.CityID
                WHERE i.ProductID=@ProductID AND i.QuantityOnHand>i.QuantityReserved
                ORDER BY CASE WHEN ci.CountryID=@DestinationCountry THEN 0 ELSE 1 END,
                         i.QuantityOnHand-i.QuantityReserved DESC, i.WarehouseID;
                IF @WarehouseID IS NULL THROW 51102, 'Insufficient available stock; allocation rolled back.', 1;
                SET @Take=CASE WHEN @Available>@Remaining THEN @Remaining ELSE @Available END;
                UPDATE dbo.Inventory
                SET QuantityReserved=QuantityReserved+@Take,UpdatedAt=SYSUTCDATETIME()
                WHERE WarehouseID=@WarehouseID AND ProductID=@ProductID AND QuantityOnHand-QuantityReserved>=@Take;
                IF @@ROWCOUNT<>1 THROW 51103, 'Concurrent inventory change; retry allocation.', 1;
                INSERT INTO dbo.InventoryReservations(OrderItemID,WarehouseID,Quantity,ReservationStatus)
                VALUES(@OrderItemID,@WarehouseID,@Take,'ACTIVE');
                SET @FulfillmentID=NULL;
                SELECT @FulfillmentID=FulfillmentID FROM dbo.OrderFulfillments WHERE OrderID=@OrderID AND WarehouseID=@WarehouseID;
                IF @FulfillmentID IS NULL
                BEGIN
                    INSERT INTO dbo.OrderFulfillments(OrderID,WarehouseID,FulfillmentStatus)
                    VALUES(@OrderID,@WarehouseID,'PICKING');
                    SET @FulfillmentID=SCOPE_IDENTITY();
                END;
                INSERT INTO dbo.FulfillmentItems(FulfillmentID,OrderItemID,Quantity)
                VALUES(@FulfillmentID,@OrderItemID,@Take);
                SET @Remaining=@Remaining-@Take;
            END;
            FETCH NEXT FROM ItemCursor INTO @OrderItemID,@ProductID,@Quantity;
        END;
        CLOSE ItemCursor;
        DEALLOCATE ItemCursor;
        UPDATE dbo.SalesOrders SET OrderStatus='RESERVED' WHERE OrderID=@OrderID;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails)
        VALUES('ORDER_ALLOCATED','SalesOrder',@OrderID,N'{"policy":"domestic-first; split fulfillment allowed"}');
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ItemCursor')>=0 CLOSE ItemCursor;
        IF CURSOR_STATUS('local','ItemCursor')>=-1 DEALLOCATE ItemCursor;
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_DispatchFulfillment
    @FulfillmentID BIGINT,
    @CarrierID SMALLINT,
    @TrackingNumber VARCHAR(60)=NULL,
    @ShipmentID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OrderID BIGINT,@WarehouseID INT,@Status VARCHAR(12),@Days INT;
    DECLARE @Now DATETIME2(0)=SYSUTCDATETIME();
    BEGIN TRY
        BEGIN TRAN;
        SELECT @OrderID=OrderID,@WarehouseID=WarehouseID,@Status=FulfillmentStatus
        FROM dbo.OrderFulfillments WITH (UPDLOCK,HOLDLOCK) WHERE FulfillmentID=@FulfillmentID;
        IF @Status IS NULL OR @Status<>'PICKING' THROW 51200, 'Fulfillment is not in PICKING state.', 1;
        SELECT @Days=StandardDeliveryDays FROM dbo.Carriers WHERE CarrierID=@CarrierID;
        IF @Days IS NULL THROW 51201, 'Carrier not found.', 1;
        IF NOT EXISTS(SELECT 1 FROM dbo.FulfillmentItems WHERE FulfillmentID=@FulfillmentID)
            THROW 51202, 'Fulfillment has no lines.', 1;
        IF EXISTS(
            SELECT 1 FROM dbo.FulfillmentItems fi
            LEFT JOIN dbo.InventoryReservations r ON r.OrderItemID=fi.OrderItemID AND r.WarehouseID=@WarehouseID AND r.ReservationStatus='ACTIVE' AND r.Quantity=fi.Quantity
            WHERE fi.FulfillmentID=@FulfillmentID AND r.ReservationID IS NULL
        ) THROW 51203, 'Active reservation missing or inconsistent.', 1;
        IF EXISTS(
            SELECT 1 FROM (
                SELECT oi.ProductID,SUM(fi.Quantity) Qty
                FROM dbo.FulfillmentItems fi JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=fi.OrderItemID
                WHERE fi.FulfillmentID=@FulfillmentID GROUP BY oi.ProductID
            ) x LEFT JOIN dbo.Inventory i WITH (UPDLOCK,HOLDLOCK)
            ON i.WarehouseID=@WarehouseID AND i.ProductID=x.ProductID
            WHERE i.ProductID IS NULL OR i.QuantityOnHand<x.Qty OR i.QuantityReserved<x.Qty
        ) THROW 51204, 'Insufficient reserved inventory for dispatch.', 1;
        ;WITH QuantityByProduct AS (
            SELECT oi.ProductID,SUM(fi.Quantity) Qty
            FROM dbo.FulfillmentItems fi JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=fi.OrderItemID
            WHERE fi.FulfillmentID=@FulfillmentID GROUP BY oi.ProductID
        )
        UPDATE i SET i.QuantityOnHand=i.QuantityOnHand-q.Qty,
                     i.QuantityReserved=i.QuantityReserved-q.Qty,i.UpdatedAt=@Now
        FROM dbo.Inventory i JOIN QuantityByProduct q ON q.ProductID=i.ProductID
        WHERE i.WarehouseID=@WarehouseID;
        INSERT INTO dbo.InventoryMovements(WarehouseID,ProductID,QuantityDelta,MovementType,ReferenceType,ReferenceID,OccurredAt)
        SELECT @WarehouseID,oi.ProductID,-SUM(fi.Quantity),'SALE','Fulfillment',@FulfillmentID,@Now
        FROM dbo.FulfillmentItems fi JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=fi.OrderItemID
        WHERE fi.FulfillmentID=@FulfillmentID GROUP BY oi.ProductID;
        UPDATE r SET ReservationStatus='CONSUMED'
        FROM dbo.InventoryReservations r
        JOIN dbo.FulfillmentItems fi ON fi.OrderItemID=r.OrderItemID
        WHERE fi.FulfillmentID=@FulfillmentID AND r.WarehouseID=@WarehouseID AND r.ReservationStatus='ACTIVE';
        SET @TrackingNumber=COALESCE(@TrackingNumber,CONCAT('ROTRK-',CONVERT(VARCHAR(36),NEWID())));
        INSERT INTO dbo.Shipments(FulfillmentID,CarrierID,TrackingNumber,ShipmentStatus,ShippedAt,ExpectedDeliveryAt)
        VALUES(@FulfillmentID,@CarrierID,@TrackingNumber,'IN_TRANSIT',@Now,DATEADD(DAY,@Days,@Now));
        SET @ShipmentID=SCOPE_IDENTITY();
        UPDATE dbo.OrderFulfillments SET FulfillmentStatus='DISPATCHED' WHERE FulfillmentID=@FulfillmentID;
        UPDATE dbo.SalesOrders SET OrderStatus=CASE
            WHEN EXISTS(SELECT 1 FROM dbo.OrderFulfillments WHERE OrderID=@OrderID AND FulfillmentStatus='PICKING') THEN 'PARTIAL'
            ELSE 'SHIPPED' END WHERE OrderID=@OrderID;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails)
        VALUES('FULFILLMENT_DISPATCHED','Fulfillment',@FulfillmentID,CONCAT('{"shipmentId":',@ShipmentID,'}'));
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MarkShipmentDelivered
    @ShipmentID BIGINT,
    @DeliveredAt DATETIME2(0)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @FulfillmentID BIGINT,@OrderID BIGINT,@ShippedAt DATETIME2(0),@Status VARCHAR(12);
    SET @DeliveredAt=COALESCE(@DeliveredAt,SYSUTCDATETIME());
    BEGIN TRY
        BEGIN TRAN;
        SELECT @FulfillmentID=s.FulfillmentID,@ShippedAt=s.ShippedAt,@Status=s.ShipmentStatus,@OrderID=f.OrderID
        FROM dbo.Shipments s WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.OrderFulfillments f ON f.FulfillmentID=s.FulfillmentID
        WHERE s.ShipmentID=@ShipmentID;
        IF @Status IS NULL OR @Status<>'IN_TRANSIT' THROW 51300, 'Shipment not in transit.', 1;
        IF @DeliveredAt<@ShippedAt THROW 51301, 'Delivery date is before shipment.', 1;
        UPDATE dbo.Shipments SET ShipmentStatus='DELIVERED',DeliveredAt=@DeliveredAt WHERE ShipmentID=@ShipmentID;
        UPDATE dbo.OrderFulfillments SET FulfillmentStatus='DELIVERED' WHERE FulfillmentID=@FulfillmentID;
        UPDATE dbo.SalesOrders SET OrderStatus=CASE
           WHEN NOT EXISTS(SELECT 1 FROM dbo.OrderFulfillments WHERE OrderID=@OrderID AND FulfillmentStatus<>'DELIVERED') THEN 'DELIVERED'
           WHEN EXISTS(SELECT 1 FROM dbo.OrderFulfillments WHERE OrderID=@OrderID AND FulfillmentStatus='PICKING') THEN 'PARTIAL'
           ELSE 'SHIPPED' END WHERE OrderID=@OrderID;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails)
        VALUES('SHIPMENT_DELIVERED','Shipment',@ShipmentID,NULL);
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CancelOrder
    @OrderID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Status VARCHAR(12);
    BEGIN TRY
        BEGIN TRAN;
        SELECT @Status=OrderStatus FROM dbo.SalesOrders WITH (UPDLOCK,HOLDLOCK) WHERE OrderID=@OrderID;
        IF @Status IS NULL OR @Status NOT IN ('NEW','RESERVED') THROW 51400, 'Only NEW/RESERVED orders may be cancelled.', 1;
        ;WITH ReservedByProduct AS (
            SELECT r.WarehouseID,oi.ProductID,SUM(r.Quantity) Qty
            FROM dbo.InventoryReservations r
            JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=r.OrderItemID
            WHERE oi.OrderID=@OrderID AND r.ReservationStatus='ACTIVE'
            GROUP BY r.WarehouseID,oi.ProductID
        )
        UPDATE i SET i.QuantityReserved=i.QuantityReserved-q.Qty,i.UpdatedAt=SYSUTCDATETIME()
        FROM dbo.Inventory i JOIN ReservedByProduct q ON q.WarehouseID=i.WarehouseID AND q.ProductID=i.ProductID;
        UPDATE r SET ReservationStatus='RELEASED' FROM dbo.InventoryReservations r
        JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=r.OrderItemID
        WHERE oi.OrderID=@OrderID AND r.ReservationStatus='ACTIVE';
        UPDATE dbo.OrderFulfillments SET FulfillmentStatus='CANCELLED' WHERE OrderID=@OrderID AND FulfillmentStatus='PICKING';
        UPDATE dbo.SalesOrders SET OrderStatus='CANCELLED' WHERE OrderID=@OrderID;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails) VALUES('ORDER_CANCELLED','SalesOrder',@OrderID,NULL);
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ReceivePurchaseOrderItem
    @PurchaseOrderItemID BIGINT,
    @Quantity INT,
    @ReceiptReference VARCHAR(80)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @POID BIGINT,@WarehouseID INT,@ProductID INT,@Ordered INT,@Already INT,@Status VARCHAR(12),@ReceiptID BIGINT;
    BEGIN TRY
        BEGIN TRAN;
        SELECT @POID=po.PurchaseOrderID,@WarehouseID=po.WarehouseID,@ProductID=pi.ProductID,
               @Ordered=pi.QuantityOrdered,@Status=po.PurchaseStatus
        FROM dbo.PurchaseOrderItems pi WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.PurchaseOrders po WITH (UPDLOCK,HOLDLOCK) ON po.PurchaseOrderID=pi.PurchaseOrderID
        WHERE pi.PurchaseOrderItemID=@PurchaseOrderItemID;
        IF @Status IS NULL OR @Status NOT IN ('APPROVED','PARTIAL') THROW 51500, 'PO item not found or PO not receivable.', 1;
        IF @Quantity IS NULL OR @Quantity<=0 THROW 51501, 'Receipt quantity must be positive.', 1;
        SELECT @Already=COALESCE(SUM(QuantityReceived),0) FROM dbo.GoodsReceipts WITH (UPDLOCK,HOLDLOCK)
        WHERE PurchaseOrderItemID=@PurchaseOrderItemID;
        IF @Quantity>@Ordered-@Already THROW 51502, 'Receipt would exceed ordered quantity.', 1;
        INSERT INTO dbo.GoodsReceipts(PurchaseOrderItemID,QuantityReceived,ReceiptReference)
        VALUES(@PurchaseOrderItemID,@Quantity,@ReceiptReference);
        SET @ReceiptID=SCOPE_IDENTITY();
        UPDATE dbo.Inventory WITH (UPDLOCK,HOLDLOCK)
        SET QuantityOnHand=QuantityOnHand+@Quantity,UpdatedAt=SYSUTCDATETIME()
        WHERE WarehouseID=@WarehouseID AND ProductID=@ProductID;
        IF @@ROWCOUNT=0
            INSERT INTO dbo.Inventory(WarehouseID,ProductID,QuantityOnHand,QuantityReserved)
            VALUES(@WarehouseID,@ProductID,@Quantity,0);
        INSERT INTO dbo.InventoryMovements(WarehouseID,ProductID,QuantityDelta,MovementType,ReferenceType,ReferenceID)
        VALUES(@WarehouseID,@ProductID,@Quantity,'RECEIPT','GoodsReceipt',@ReceiptID);
        UPDATE po SET PurchaseStatus=CASE WHEN NOT EXISTS(
                SELECT 1 FROM dbo.PurchaseOrderItems pi
                OUTER APPLY (SELECT COALESCE(SUM(QuantityReceived),0) Received FROM dbo.GoodsReceipts WHERE PurchaseOrderItemID=pi.PurchaseOrderItemID) x
                WHERE pi.PurchaseOrderID=@POID AND x.Received<pi.QuantityOrdered
            ) THEN 'RECEIVED' ELSE 'PARTIAL' END
        FROM dbo.PurchaseOrders po WHERE po.PurchaseOrderID=@POID;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails)
        VALUES('GOODS_RECEIVED','GoodsReceipt',@ReceiptID,CONCAT('{"quantity":',@Quantity,'}'));
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ReceiveReturn
    @ReturnID BIGINT,
    @ProcessingWarehouseID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @OrderID BIGINT,@Status VARCHAR(12);
    BEGIN TRY
        BEGIN TRAN;
        SELECT @OrderID=OrderID,@Status=ReturnStatus FROM dbo.ReturnRequests WITH (UPDLOCK,HOLDLOCK) WHERE ReturnID=@ReturnID;
        IF @Status IS NULL OR @Status<>'APPROVED' THROW 51600, 'Return must be APPROVED.', 1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Warehouses WHERE WarehouseID=@ProcessingWarehouseID AND IsActive=1)
            THROW 51601, 'Processing warehouse invalid.', 1;
        IF NOT EXISTS(SELECT 1 FROM dbo.SalesOrders WHERE OrderID=@OrderID AND OrderStatus='DELIVERED')
            THROW 51602, 'Order must be delivered before return is received.', 1;
        IF NOT EXISTS(SELECT 1 FROM dbo.ReturnItems WHERE ReturnID=@ReturnID)
            THROW 51603, 'Return has no lines.', 1;
        IF EXISTS(SELECT 1 FROM dbo.ReturnItems ri JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=ri.OrderItemID WHERE ri.ReturnID=@ReturnID AND oi.OrderID<>@OrderID)
            THROW 51604, 'Return contains an item from a different order.', 1;
        IF EXISTS(
            SELECT 1 FROM dbo.ReturnItems ri JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=ri.OrderItemID
            OUTER APPLY (
                SELECT COALESCE(SUM(ri2.Quantity),0) TotalReturned
                FROM dbo.ReturnItems ri2 JOIN dbo.ReturnRequests rr2 ON rr2.ReturnID=ri2.ReturnID
                WHERE ri2.OrderItemID=oi.OrderItemID AND rr2.ReturnStatus IN ('APPROVED','RECEIVED')
            ) r WHERE ri.ReturnID=@ReturnID AND r.TotalReturned>oi.Quantity
        ) THROW 51605, 'Returned quantity exceeds purchased quantity.', 1;
        DECLARE @Restock TABLE(ProductID INT PRIMARY KEY, Qty INT NOT NULL);
        INSERT INTO @Restock(ProductID,Qty)
        SELECT oi.ProductID,SUM(ri.Quantity)
        FROM dbo.ReturnItems ri JOIN dbo.SalesOrderItems oi ON oi.OrderItemID=ri.OrderItemID
        WHERE ri.ReturnID=@ReturnID AND ri.Disposition='RESTOCK' GROUP BY oi.ProductID;
        UPDATE i SET i.QuantityOnHand=i.QuantityOnHand+r.Qty,i.UpdatedAt=SYSUTCDATETIME()
        FROM dbo.Inventory i JOIN @Restock r ON r.ProductID=i.ProductID
        WHERE i.WarehouseID=@ProcessingWarehouseID;
        INSERT INTO dbo.Inventory(WarehouseID,ProductID,QuantityOnHand,QuantityReserved)
        SELECT @ProcessingWarehouseID,r.ProductID,r.Qty,0
        FROM @Restock r WHERE NOT EXISTS(
            SELECT 1 FROM dbo.Inventory WITH (UPDLOCK,HOLDLOCK) WHERE WarehouseID=@ProcessingWarehouseID AND ProductID=r.ProductID
        );
        INSERT INTO dbo.InventoryMovements(WarehouseID,ProductID,QuantityDelta,MovementType,ReferenceType,ReferenceID)
        SELECT @ProcessingWarehouseID,ProductID,Qty,'RETURN','ReturnRequest',@ReturnID FROM @Restock;
        UPDATE dbo.ReturnRequests SET ReturnStatus='RECEIVED',ProcessedAt=SYSUTCDATETIME() WHERE ReturnID=@ReturnID;
        INSERT INTO dbo.AuditEvents(EventType,EntityType,EntityID,EventDetails)
        VALUES('RETURN_RECEIVED','ReturnRequest',@ReturnID,CONCAT('{"warehouseId":',@ProcessingWarehouseID,'}'));
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
IF (
    SELECT COUNT(*)
    FROM sys.procedures
    WHERE schema_id = SCHEMA_ID(N'dbo')
      AND name IN (
          N'usp_CreateOrder', N'usp_AllocateOrder', N'usp_DispatchFulfillment',
          N'usp_MarkShipmentDelivered', N'usp_CancelOrder',
          N'usp_ReceivePurchaseOrderItem', N'usp_ReceiveReturn'
      )
) <> 7
    THROW 51999, 'Procedure installation incomplete. Review earlier Messages errors.', 1;
PRINT 'PASS: All seven operational stored procedures are present.';
GO
