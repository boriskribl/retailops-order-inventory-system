/* RetailOps C01 -- SECOND SSMS QUERY WINDOW (connection B).
   Change 0 to OrderB from 01_setup.sql.
   Execute while session A reports it is holding inventory locks.
   The expected outcome is error 51102 caught and reported as PASS. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
DECLARE @OrderB BIGINT = 0;  -- REPLACE 0 WITH OrderB
IF @OrderB <= 0
    THROW 54620, 'Enter OrderB from the setup result before running.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.SalesOrders
               WHERE OrderID = @OrderB AND ExternalRequestKey LIKE 'CONC-%-B'
                 AND OrderStatus = 'NEW')
    THROW 54621, 'OrderB is not an unused concurrency-test order.', 1;
DECLARE @StartedAt DATETIME2(3) = SYSUTCDATETIME();
DECLARE @ErrorNumber INT = NULL;
BEGIN TRY
    EXEC dbo.usp_AllocateOrder @OrderID = @OrderB;
END TRY
BEGIN CATCH
    SET @ErrorNumber = ERROR_NUMBER();
    IF @ErrorNumber <> 51102 THROW;
END CATCH;

DECLARE @ElapsedMs INT = DATEDIFF(MILLISECOND, @StartedAt, SYSUTCDATETIME());
IF @ErrorNumber = 51102 AND @ElapsedMs >= 3000
    PRINT 'PASS C01: session B waited and then correctly rejected excess allocation (51102).';
ELSE IF @ErrorNumber = 51102
    PRINT 'INCONCLUSIVE C01: excess allocation was rejected, but simultaneous blocking was not demonstrated.';
ELSE
    THROW 54622, 'FAIL C01: both orders allocated from the same starting stock.', 1;
SELECT @ErrorNumber AS ErrorNumber, @ElapsedMs AS DurationMilliseconds;
