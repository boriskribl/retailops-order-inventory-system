/* RetailOps C01 -- Concurrency experiment setup.
   Creates TWO test orders for the SAME active SKU. It does not modify inventory.
   Run once in RetailOpsDB, then note OrderA and OrderB in the result grid.
   Do not rerun after success; each execution creates another pair of orders. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProductID INT, @RequestedQty INT;
;WITH Available AS (
    SELECT i.ProductID,
           SUM(CONVERT(BIGINT, i.QuantityOnHand) - CONVERT(BIGINT, i.QuantityReserved)) AS Units
    FROM dbo.Inventory AS i
    INNER JOIN dbo.Products AS p ON p.ProductID = i.ProductID AND p.IsActive = 1
    INNER JOIN dbo.Warehouses AS w ON w.WarehouseID = i.WarehouseID AND w.IsActive = 1
    GROUP BY i.ProductID
)
SELECT TOP (1) @ProductID = ProductID, @RequestedQty = CONVERT(INT, Units)
FROM Available
WHERE Units BETWEEN 1 AND 2147483647
ORDER BY Units, ProductID;
IF @ProductID IS NULL
    THROW 54600, 'No SKU with usable stock found. Stop and inspect inventory.', 1;

DECLARE @CustomerID INT, @AddressID INT;
SELECT TOP (1) @CustomerID = ca.CustomerID, @AddressID = ca.AddressID
FROM dbo.CustomerAddresses AS ca
INNER JOIN dbo.Customers AS c ON c.CustomerID = ca.CustomerID
ORDER BY ca.AddressID;
IF @AddressID IS NULL
    THROW 54601, 'No valid customer shipping address found.', 1;

DECLARE @Pair VARCHAR(32) = REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', '');
DECLARE @KeyA VARCHAR(80) = CONCAT('CONC-', @Pair, '-A');
DECLARE @KeyB VARCHAR(80) = CONCAT('CONC-', @Pair, '-B');
DECLARE @Json NVARCHAR(MAX) = CONCAT(N'[{"ProductID":', @ProductID,
                                      N',"Quantity":', @RequestedQty, N'}]');
DECLARE @OrderA BIGINT, @OrderB BIGINT;

BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.usp_CreateOrder
        @CustomerID = @CustomerID, @ShipAddressID = @AddressID,
        @SalesChannel = 'ONLINE', @ItemsJson = @Json,
        @ExternalRequestKey = @KeyA, @OrderID = @OrderA OUTPUT;
    EXEC dbo.usp_CreateOrder
        @CustomerID = @CustomerID, @ShipAddressID = @AddressID,
        @SalesChannel = 'ONLINE', @ItemsJson = @Json,
        @ExternalRequestKey = @KeyB, @OrderID = @OrderB OUTPUT;
    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH;

SELECT @OrderA AS OrderA, @OrderB AS OrderB,
       @ProductID AS ProductID, @RequestedQty AS UnitsPerOrder,
       @KeyA AS KeyA, @KeyB AS KeyB;
PRINT 'SETUP OK: record OrderA and OrderB. Run session A, then session B while A holds locks.';
