/* RetailOps | 01 | Data model: 25 related tables
   Run once on a clean RetailOpsDB. Never run blindly on production data. */
USE RetailOpsDB;
GO
SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.Countries',N'U') IS NOT NULL
    THROW 50001, 'Schema already exists. Do not rerun schema on an existing database.', 1;
GO
CREATE TABLE dbo.Countries (
    CountryID TINYINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Countries PRIMARY KEY,
    ISOCode CHAR(2) NOT NULL CONSTRAINT UQ_Countries_ISO UNIQUE,
    CountryName NVARCHAR(80) NOT NULL,
    CurrencyCode CHAR(3) NOT NULL
);
CREATE TABLE dbo.Cities (
    CityID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cities PRIMARY KEY,
    CountryID TINYINT NOT NULL CONSTRAINT FK_Cities_Countries REFERENCES dbo.Countries(CountryID),
    CityName NVARCHAR(120) NOT NULL,
    CONSTRAINT UQ_Cities UNIQUE(CountryID,CityName)
);
CREATE TABLE dbo.Stores (
    StoreID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Stores PRIMARY KEY,
    CityID INT NOT NULL CONSTRAINT FK_Stores_Cities REFERENCES dbo.Cities(CityID),
    StoreCode VARCHAR(20) NOT NULL CONSTRAINT UQ_Stores_Code UNIQUE,
    StoreName NVARCHAR(120) NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Stores_IsActive DEFAULT(1)
);
CREATE TABLE dbo.Warehouses (
    WarehouseID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Warehouses PRIMARY KEY,
    CityID INT NOT NULL CONSTRAINT FK_Warehouses_Cities REFERENCES dbo.Cities(CityID),
    WarehouseCode VARCHAR(20) NOT NULL CONSTRAINT UQ_Warehouses_Code UNIQUE,
    WarehouseName NVARCHAR(120) NOT NULL,
    CapacityUnits INT NOT NULL CONSTRAINT CK_Warehouses_Capacity CHECK(CapacityUnits>0),
    IsActive BIT NOT NULL CONSTRAINT DF_Warehouses_Active DEFAULT(1)
);
CREATE TABLE dbo.Customers (
    CustomerID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    HomeCountryID TINYINT NOT NULL CONSTRAINT FK_Customers_Country REFERENCES dbo.Countries(CountryID),
    FullName NVARCHAR(150) NOT NULL,
    Email VARCHAR(240) NOT NULL CONSTRAINT UQ_Customers_Email UNIQUE,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Customers_Created DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.CustomerAddresses (
    AddressID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerAddresses PRIMARY KEY,
    CustomerID INT NOT NULL CONSTRAINT FK_Addresses_Customer REFERENCES dbo.Customers(CustomerID),
    CityID INT NOT NULL CONSTRAINT FK_Addresses_City REFERENCES dbo.Cities(CityID),
    StreetLine NVARCHAR(200) NOT NULL,
    PostalCode NVARCHAR(20) NOT NULL,
    IsDefault BIT NOT NULL CONSTRAINT DF_Addresses_Default DEFAULT(1)
);
CREATE TABLE dbo.Categories (
    CategoryID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL CONSTRAINT UQ_Categories_Name UNIQUE,
    ParentCategoryID INT NULL CONSTRAINT FK_Categories_Parent REFERENCES dbo.Categories(CategoryID)
);
CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    SKU VARCHAR(40) NOT NULL CONSTRAINT UQ_Products_SKU UNIQUE,
    CategoryID INT NOT NULL CONSTRAINT FK_Products_Category REFERENCES dbo.Categories(CategoryID),
    ProductName NVARCHAR(160) NOT NULL,
    UnitPriceEUR DECIMAL(12,2) NOT NULL CONSTRAINT CK_Products_Price CHECK(UnitPriceEUR>0),
    UnitCostEUR DECIMAL(12,2) NOT NULL CONSTRAINT CK_Products_Cost CHECK(UnitCostEUR>=0),
    ReorderPoint INT NOT NULL CONSTRAINT CK_Products_ReorderPoint CHECK(ReorderPoint>=0),
    ReorderQuantity INT NOT NULL CONSTRAINT CK_Products_ReorderQty CHECK(ReorderQuantity>0),
    IsActive BIT NOT NULL CONSTRAINT DF_Products_Active DEFAULT(1),
    CONSTRAINT CK_Products_CostLessPrice CHECK(UnitCostEUR<=UnitPriceEUR)
);
CREATE TABLE dbo.Suppliers (
    SupplierID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Suppliers PRIMARY KEY,
    CountryID TINYINT NOT NULL CONSTRAINT FK_Suppliers_Country REFERENCES dbo.Countries(CountryID),
    SupplierCode VARCHAR(20) NOT NULL CONSTRAINT UQ_Suppliers_Code UNIQUE,
    SupplierName NVARCHAR(150) NOT NULL,
    DefaultLeadDays INT NOT NULL CONSTRAINT CK_Suppliers_Lead CHECK(DefaultLeadDays>=1),
    IsActive BIT NOT NULL CONSTRAINT DF_Suppliers_Active DEFAULT(1)
);
CREATE TABLE dbo.SupplierProducts (
    SupplierID INT NOT NULL CONSTRAINT FK_SupplierProducts_Supplier REFERENCES dbo.Suppliers(SupplierID),
    ProductID INT NOT NULL CONSTRAINT FK_SupplierProducts_Product REFERENCES dbo.Products(ProductID),
    ContractUnitCostEUR DECIMAL(12,2) NOT NULL CONSTRAINT CK_SupplierProducts_Cost CHECK(ContractUnitCostEUR>0),
    MinimumOrderQty INT NOT NULL CONSTRAINT CK_SupplierProducts_Min CHECK(MinimumOrderQty>=1),
    CONSTRAINT PK_SupplierProducts PRIMARY KEY(SupplierID, ProductID)
);
CREATE TABLE dbo.Inventory (
    WarehouseID INT NOT NULL CONSTRAINT FK_Inventory_Warehouse REFERENCES dbo.Warehouses(WarehouseID),
    ProductID INT NOT NULL CONSTRAINT FK_Inventory_Product REFERENCES dbo.Products(ProductID),
    QuantityOnHand INT NOT NULL CONSTRAINT DF_Inventory_OnHand DEFAULT(0),
    QuantityReserved INT NOT NULL CONSTRAINT DF_Inventory_Reserved DEFAULT(0),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Inventory_Updated DEFAULT SYSUTCDATETIME(),
    ChangeVersion ROWVERSION,
    CONSTRAINT PK_Inventory PRIMARY KEY(WarehouseID,ProductID),
    CONSTRAINT CK_Inventory_Quantity CHECK(QuantityOnHand>=0 AND QuantityReserved>=0 AND QuantityReserved<=QuantityOnHand)
);
CREATE TABLE dbo.InventoryMovements (
    MovementID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventoryMovements PRIMARY KEY,
    WarehouseID INT NOT NULL,
    ProductID INT NOT NULL,
    QuantityDelta INT NOT NULL CONSTRAINT CK_Movements_NonZero CHECK(QuantityDelta<>0),
    MovementType VARCHAR(20) NOT NULL CONSTRAINT CK_Movements_Type CHECK(MovementType IN ('OPENING','SALE','RECEIPT','RETURN','ADJUSTMENT')),
    ReferenceType VARCHAR(30) NULL,
    ReferenceID BIGINT NULL,
    OccurredAt DATETIME2(0) NOT NULL CONSTRAINT DF_Movements_Time DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Movements_Inventory FOREIGN KEY(WarehouseID,ProductID) REFERENCES dbo.Inventory(WarehouseID,ProductID)
);
CREATE TABLE dbo.SalesOrders (
    OrderID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesOrders PRIMARY KEY,
    OrderNumber VARCHAR(40) NOT NULL CONSTRAINT UQ_SalesOrders_Number UNIQUE,
    ExternalRequestKey VARCHAR(80) NULL,
    CustomerID INT NOT NULL CONSTRAINT FK_Orders_Customer REFERENCES dbo.Customers(CustomerID),
    ShipAddressID INT NOT NULL CONSTRAINT FK_Orders_Address REFERENCES dbo.CustomerAddresses(AddressID),
    StoreID INT NULL CONSTRAINT FK_Orders_Store REFERENCES dbo.Stores(StoreID),
    SalesChannel VARCHAR(10) NOT NULL CONSTRAINT CK_Orders_Channel CHECK(SalesChannel IN ('ONLINE','STORE')),
    OrderStatus VARCHAR(12) NOT NULL CONSTRAINT CK_Orders_Status CHECK(OrderStatus IN ('NEW','RESERVED','PARTIAL','SHIPPED','DELIVERED','CANCELLED')),
    OrderedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_Ordered DEFAULT SYSUTCDATETIME()
);
CREATE UNIQUE INDEX UX_SalesOrders_ExternalRequestKey ON dbo.SalesOrders(ExternalRequestKey) WHERE ExternalRequestKey IS NOT NULL;
CREATE TABLE dbo.SalesOrderItems (
    OrderItemID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderID BIGINT NOT NULL CONSTRAINT FK_OrderItems_Order REFERENCES dbo.SalesOrders(OrderID),
    ProductID INT NOT NULL CONSTRAINT FK_OrderItems_Product REFERENCES dbo.Products(ProductID),
    Quantity INT NOT NULL CONSTRAINT CK_OrderItems_Quantity CHECK(Quantity>0),
    UnitPriceEUR DECIMAL(12,2) NOT NULL CONSTRAINT CK_OrderItems_Price CHECK(UnitPriceEUR>0),
    UnitCostEUR DECIMAL(12,2) NOT NULL CONSTRAINT CK_OrderItems_Cost CHECK(UnitCostEUR>=0),
    CONSTRAINT UQ_OrderItems_OrderProduct UNIQUE(OrderID,ProductID)
);
CREATE TABLE dbo.InventoryReservations (
    ReservationID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Reservations PRIMARY KEY,
    OrderItemID BIGINT NOT NULL CONSTRAINT FK_Reservations_OrderItem REFERENCES dbo.SalesOrderItems(OrderItemID),
    WarehouseID INT NOT NULL CONSTRAINT FK_Reservations_Warehouse REFERENCES dbo.Warehouses(WarehouseID),
    Quantity INT NOT NULL CONSTRAINT CK_Reservations_Qty CHECK(Quantity>0),
    ReservationStatus VARCHAR(10) NOT NULL CONSTRAINT CK_Reservations_Status CHECK(ReservationStatus IN ('ACTIVE','CONSUMED','RELEASED')),
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Reservations_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Reservations_ItemWarehouse UNIQUE(OrderItemID,WarehouseID)
);
CREATE TABLE dbo.OrderFulfillments (
    FulfillmentID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fulfillments PRIMARY KEY,
    OrderID BIGINT NOT NULL CONSTRAINT FK_Fulfillments_Order REFERENCES dbo.SalesOrders(OrderID),
    WarehouseID INT NOT NULL CONSTRAINT FK_Fulfillments_Warehouse REFERENCES dbo.Warehouses(WarehouseID),
    FulfillmentStatus VARCHAR(12) NOT NULL CONSTRAINT CK_Fulfillments_Status CHECK(FulfillmentStatus IN ('PICKING','DISPATCHED','DELIVERED','CANCELLED')),
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Fulfillments_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Fulfillments_OrderWarehouse UNIQUE(OrderID,WarehouseID)
);
CREATE TABLE dbo.FulfillmentItems (
    FulfillmentItemID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FulfillmentItems PRIMARY KEY,
    FulfillmentID BIGINT NOT NULL CONSTRAINT FK_FulfillmentItems_Fulfillment REFERENCES dbo.OrderFulfillments(FulfillmentID),
    OrderItemID BIGINT NOT NULL CONSTRAINT FK_FulfillmentItems_OrderItem REFERENCES dbo.SalesOrderItems(OrderItemID),
    Quantity INT NOT NULL CONSTRAINT CK_FulfillmentItems_Qty CHECK(Quantity>0),
    CONSTRAINT UQ_FulfillmentItems UNIQUE(FulfillmentID,OrderItemID)
);
CREATE TABLE dbo.Carriers (
    CarrierID SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Carriers PRIMARY KEY,
    CarrierName NVARCHAR(100) NOT NULL CONSTRAINT UQ_Carriers_Name UNIQUE,
    StandardDeliveryDays INT NOT NULL CONSTRAINT CK_Carriers_Days CHECK(StandardDeliveryDays>=1)
);
CREATE TABLE dbo.Shipments (
    ShipmentID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Shipments PRIMARY KEY,
    FulfillmentID BIGINT NOT NULL CONSTRAINT FK_Shipments_Fulfillment REFERENCES dbo.OrderFulfillments(FulfillmentID),
    CarrierID SMALLINT NOT NULL CONSTRAINT FK_Shipments_Carrier REFERENCES dbo.Carriers(CarrierID),
    TrackingNumber VARCHAR(60) NOT NULL CONSTRAINT UQ_Shipments_Tracking UNIQUE,
    ShipmentStatus VARCHAR(12) NOT NULL CONSTRAINT CK_Shipments_Status CHECK(ShipmentStatus IN ('IN_TRANSIT','DELIVERED','LOST')),
    ShippedAt DATETIME2(0) NOT NULL,
    ExpectedDeliveryAt DATETIME2(0) NOT NULL,
    DeliveredAt DATETIME2(0) NULL,
    CONSTRAINT UQ_Shipments_Fulfillment UNIQUE(FulfillmentID),
    CONSTRAINT CK_Shipments_Dates CHECK(ExpectedDeliveryAt>=ShippedAt AND (DeliveredAt IS NULL OR DeliveredAt>=ShippedAt)),
    CONSTRAINT CK_Shipments_DeliveryStatus CHECK((ShipmentStatus='DELIVERED' AND DeliveredAt IS NOT NULL) OR (ShipmentStatus<>'DELIVERED' AND DeliveredAt IS NULL))
);
CREATE TABLE dbo.PurchaseOrders (
    PurchaseOrderID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PurchaseOrders PRIMARY KEY,
    SupplierID INT NOT NULL CONSTRAINT FK_PurchaseOrders_Supplier REFERENCES dbo.Suppliers(SupplierID),
    WarehouseID INT NOT NULL CONSTRAINT FK_PurchaseOrders_Warehouse REFERENCES dbo.Warehouses(WarehouseID),
    PurchaseOrderNumber VARCHAR(40) NOT NULL CONSTRAINT UQ_PurchaseOrders_Number UNIQUE,
    PurchaseStatus VARCHAR(12) NOT NULL CONSTRAINT CK_PurchaseOrders_Status CHECK(PurchaseStatus IN ('DRAFT','APPROVED','PARTIAL','RECEIVED','CANCELLED')),
    OrderedAt DATETIME2(0) NOT NULL CONSTRAINT DF_PurchaseOrders_Date DEFAULT SYSUTCDATETIME(),
    ExpectedAt DATETIME2(0) NULL
);
CREATE TABLE dbo.PurchaseOrderItems (
    PurchaseOrderItemID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PurchaseOrderItems PRIMARY KEY,
    PurchaseOrderID BIGINT NOT NULL CONSTRAINT FK_POItems_Order REFERENCES dbo.PurchaseOrders(PurchaseOrderID),
    ProductID INT NOT NULL CONSTRAINT FK_POItems_Product REFERENCES dbo.Products(ProductID),
    QuantityOrdered INT NOT NULL CONSTRAINT CK_POItems_Quantity CHECK(QuantityOrdered>0),
    UnitCostEUR DECIMAL(12,2) NOT NULL CONSTRAINT CK_POItems_Cost CHECK(UnitCostEUR>0),
    CONSTRAINT UQ_POItems_Product UNIQUE(PurchaseOrderID,ProductID)
);
CREATE TABLE dbo.GoodsReceipts (
    GoodsReceiptID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GoodsReceipts PRIMARY KEY,
    PurchaseOrderItemID BIGINT NOT NULL CONSTRAINT FK_Receipts_POItem REFERENCES dbo.PurchaseOrderItems(PurchaseOrderItemID),
    QuantityReceived INT NOT NULL CONSTRAINT CK_Receipts_Quantity CHECK(QuantityReceived>0),
    ReceivedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Receipts_Date DEFAULT SYSUTCDATETIME(),
    ReceiptReference VARCHAR(80) NOT NULL CONSTRAINT UQ_Receipts_Reference UNIQUE
);
CREATE TABLE dbo.ReturnRequests (
    ReturnID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReturnRequests PRIMARY KEY,
    OrderID BIGINT NOT NULL CONSTRAINT FK_Returns_Order REFERENCES dbo.SalesOrders(OrderID),
    ReturnStatus VARCHAR(12) NOT NULL CONSTRAINT CK_Returns_Status CHECK(ReturnStatus IN ('REQUESTED','APPROVED','REJECTED','RECEIVED')),
    RequestedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Returns_Requested DEFAULT SYSUTCDATETIME(),
    ProcessedAt DATETIME2(0) NULL
);
CREATE TABLE dbo.ReturnItems (
    ReturnItemID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReturnItems PRIMARY KEY,
    ReturnID BIGINT NOT NULL CONSTRAINT FK_ReturnItems_Return REFERENCES dbo.ReturnRequests(ReturnID),
    OrderItemID BIGINT NOT NULL CONSTRAINT FK_ReturnItems_OrderItem REFERENCES dbo.SalesOrderItems(OrderItemID),
    Quantity INT NOT NULL CONSTRAINT CK_ReturnItems_Quantity CHECK(Quantity>0),
    Disposition VARCHAR(8) NOT NULL CONSTRAINT CK_ReturnItems_Disposition CHECK(Disposition IN ('RESTOCK','SCRAP')),
    CONSTRAINT UQ_ReturnItems_OrderItem UNIQUE(ReturnID,OrderItemID)
);
CREATE TABLE dbo.AuditEvents (
    AuditEventID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditEvents PRIMARY KEY,
    EventType VARCHAR(60) NOT NULL,
    EntityType VARCHAR(40) NOT NULL,
    EntityID BIGINT NOT NULL,
    EventDetails NVARCHAR(MAX) NULL CONSTRAINT CK_AuditEvents_JSON CHECK(EventDetails IS NULL OR ISJSON(EventDetails)=1),
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_AuditEvents_Date DEFAULT SYSUTCDATETIME()
);
GO
PRINT 'RetailOps schema created: 25 tables.';
GO
