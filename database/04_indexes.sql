/* RetailOps | 04 | Workload-driven indexes (after bulk seed for faster loading). */
USE RetailOpsDB;
GO
CREATE INDEX IX_Addresses_Customer ON dbo.CustomerAddresses(CustomerID) INCLUDE(CityID);
CREATE INDEX IX_Orders_OrderedAtStatus ON dbo.SalesOrders(OrderedAt,OrderStatus) INCLUDE(CustomerID,SalesChannel,ShipAddressID);
CREATE INDEX IX_Orders_CustomerDate ON dbo.SalesOrders(CustomerID,OrderedAt DESC) INCLUDE(OrderStatus);
CREATE INDEX IX_OrderItems_ProductOrder ON dbo.SalesOrderItems(ProductID,OrderID) INCLUDE(Quantity,UnitPriceEUR,UnitCostEUR);
CREATE INDEX IX_OrderItems_Order ON dbo.SalesOrderItems(OrderID) INCLUDE(ProductID,Quantity,UnitPriceEUR,UnitCostEUR);
CREATE INDEX IX_Inventory_ByProduct ON dbo.Inventory(ProductID,WarehouseID) INCLUDE(QuantityOnHand,QuantityReserved);
CREATE INDEX IX_Reservations_ItemStatus ON dbo.InventoryReservations(OrderItemID,ReservationStatus) INCLUDE(WarehouseID,Quantity);
CREATE INDEX IX_Fulfillments_Status ON dbo.OrderFulfillments(OrderID,FulfillmentStatus) INCLUDE(WarehouseID);
CREATE INDEX IX_Shipments_StatusExpected ON dbo.Shipments(ShipmentStatus,ExpectedDeliveryAt) INCLUDE(FulfillmentID,DeliveredAt,ShippedAt);
CREATE INDEX IX_Shipments_ShippedAt ON dbo.Shipments(ShippedAt) INCLUDE(ExpectedDeliveryAt,DeliveredAt,ShipmentStatus);
CREATE INDEX IX_Movements_ProductTime ON dbo.InventoryMovements(ProductID,OccurredAt DESC) INCLUDE(WarehouseID,QuantityDelta,MovementType);
CREATE INDEX IX_POItems_Order ON dbo.PurchaseOrderItems(PurchaseOrderID) INCLUDE(ProductID,QuantityOrdered,UnitCostEUR);
CREATE INDEX IX_Receipts_POItem ON dbo.GoodsReceipts(PurchaseOrderItemID) INCLUDE(QuantityReceived,ReceivedAt);
CREATE INDEX IX_ReturnItems_OrderItem ON dbo.ReturnItems(OrderItemID) INCLUDE(ReturnID,Quantity,Disposition);
CREATE INDEX IX_Returns_OrderStatus ON dbo.ReturnRequests(OrderID,ReturnStatus) INCLUDE(ProcessedAt);
GO
PRINT 'Indexes ready.';
GO
