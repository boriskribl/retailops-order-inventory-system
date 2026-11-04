/* RetailOps C01 -- FIRST SSMS QUERY WINDOW (connection A).
   Change 0 to OrderA from 01_setup.sql. Start this query FIRST.
   It retains locks for 30 seconds, then commits. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
DECLARE @OrderA BIGINT = 0;  -- REPLACE 0 WITH OrderA
IF @OrderA <= 0
    THROW 54610, 'Enter OrderA from the setup result before running.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.SalesOrders
               WHERE OrderID = @OrderA AND ExternalRequestKey LIKE 'CONC-%-A'
                 AND OrderStatus = 'NEW')
    THROW 54611, 'OrderA is not an unused concurrency-test order.', 1;
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_AllocateOrder @OrderID = @OrderA;
    RAISERROR('SESSION A: stock reserved; start SESSION B in a DIFFERENT query window NOW.', 10, 1) WITH NOWAIT;
    WAITFOR DELAY '00:00:30';
    COMMIT TRAN;
    PRINT 'SESSION A: COMMITTED (expected).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH;
