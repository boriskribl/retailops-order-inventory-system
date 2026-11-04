/* RetailOps C01 -- Verify AFTER BOTH windows finish, then safely cancel test orders.
   Change 0 to OrderA and OrderB from setup. Cancelling restores available stock.
   Test orders remain in history with CANCELLED status; no direct inventory edits. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
DECLARE @OrderA BIGINT = 0;  -- REPLACE 0 WITH OrderA
DECLARE @OrderB BIGINT = 0;  -- REPLACE 0 WITH OrderB
IF @OrderA <= 0 OR @OrderB <= 0 OR @OrderA = @OrderB
    THROW 54630, 'Enter the distinct OrderA and OrderB from setup.', 1;
IF (SELECT COUNT(*) FROM dbo.SalesOrders
    WHERE (OrderID = @OrderA AND ExternalRequestKey LIKE 'CONC-%-A')
       OR (OrderID = @OrderB AND ExternalRequestKey LIKE 'CONC-%-B')) <> 2
    THROW 54631, 'Order IDs do not match the concurrency test pair.', 1;

SELECT OrderID, ExternalRequestKey, OrderStatus
FROM dbo.SalesOrders
WHERE OrderID IN (@OrderA, @OrderB)
ORDER BY OrderID;

-- A strong expected outcome is one RESERVED and one NEW.
IF (SELECT COUNT(*) FROM dbo.SalesOrders
    WHERE OrderID IN (@OrderA, @OrderB) AND OrderStatus = 'RESERVED') = 1
   AND (SELECT COUNT(*) FROM dbo.SalesOrders
    WHERE OrderID IN (@OrderA, @OrderB) AND OrderStatus = 'NEW') = 1
    PRINT 'PASS C01 state: one reserved, one rejected.';
ELSE
    PRINT 'REVIEW C01 state: result differs from the expected one-RESERVED/one-NEW pair.';

-- Do not cancel an order that was dispatched/delivered; stop for manual review.
IF EXISTS(SELECT 1 FROM dbo.SalesOrders
          WHERE OrderID IN (@OrderA, @OrderB) AND OrderStatus NOT IN ('NEW','RESERVED','CANCELLED'))
    THROW 54632, 'Unexpected order status; cleanup halted.', 1;

IF EXISTS(SELECT 1 FROM dbo.SalesOrders WHERE OrderID=@OrderA AND OrderStatus IN ('NEW','RESERVED'))
    EXEC dbo.usp_CancelOrder @OrderID = @OrderA;
IF EXISTS(SELECT 1 FROM dbo.SalesOrders WHERE OrderID=@OrderB AND OrderStatus IN ('NEW','RESERVED'))
    EXEC dbo.usp_CancelOrder @OrderID = @OrderB;

IF EXISTS (SELECT 1 FROM dbo.InventoryReservations r
           INNER JOIN dbo.SalesOrderItems oi ON oi.OrderItemID = r.OrderItemID
           WHERE oi.OrderID IN (@OrderA,@OrderB) AND r.ReservationStatus = 'ACTIVE')
    THROW 54633, 'Cleanup left an active test reservation.', 1;
IF EXISTS(SELECT 1 FROM dbo.Inventory WHERE QuantityReserved < 0 OR QuantityReserved > QuantityOnHand)
    THROW 54634, 'Inventory balance constraints violated.', 1;
IF (SELECT COUNT(*) FROM dbo.SalesOrders
    WHERE OrderID IN (@OrderA,@OrderB) AND OrderStatus = 'CANCELLED') <> 2
    THROW 54635, 'Test orders were not both cancelled.', 1;
PRINT 'PASS C01 cleanup: both orders CANCELLED, no active test reservations, inventory bounds valid.';
SELECT OrderID, OrderStatus FROM dbo.SalesOrders
WHERE OrderID IN (@OrderA,@OrderB) ORDER BY OrderID;
