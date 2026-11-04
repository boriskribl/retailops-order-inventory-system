# SQL data dictionary (generated from schema)

**Canonical source:** `database/01_schema.sql`. SQL Server types are shown as authored. All tables belong to `dbo`.

## Countries

| Column | Type | Nullable | Notes |
|---|---|---|---|
| CountryID | `TINYINT` | NO | Identity, PK |
| ISOCode | `CHAR(2)` | NO | Unique |
| CountryName | `NVARCHAR(80)` | NO |  |
| CurrencyCode | `CHAR(3)` | NO |  |

## Cities

| Column | Type | Nullable | Notes |
|---|---|---|---|
| CityID | `INT` | NO | Identity, PK |
| CountryID | `TINYINT` | NO | FK |
| CityName | `NVARCHAR(120)` | NO |  |

## Stores

| Column | Type | Nullable | Notes |
|---|---|---|---|
| StoreID | `INT` | NO | Identity, PK |
| CityID | `INT` | NO | FK |
| StoreCode | `VARCHAR(20)` | NO | Unique |
| StoreName | `NVARCHAR(120)` | NO |  |
| IsActive | `BIT` | NO | Default |

## Warehouses

| Column | Type | Nullable | Notes |
|---|---|---|---|
| WarehouseID | `INT` | NO | Identity, PK |
| CityID | `INT` | NO | FK |
| WarehouseCode | `VARCHAR(20)` | NO | Unique |
| WarehouseName | `NVARCHAR(120)` | NO |  |
| CapacityUnits | `INT` | NO | Check |
| IsActive | `BIT` | NO | Default |

## Customers

| Column | Type | Nullable | Notes |
|---|---|---|---|
| CustomerID | `INT` | NO | Identity, PK |
| HomeCountryID | `TINYINT` | NO | FK |
| FullName | `NVARCHAR(150)` | NO |  |
| Email | `VARCHAR(240)` | NO | Unique |

## CustomerAddresses

| Column | Type | Nullable | Notes |
|---|---|---|---|
| AddressID | `INT` | NO | Identity, PK |
| CustomerID | `INT` | NO | FK |
| CityID | `INT` | NO | FK |
| StreetLine | `NVARCHAR(200)` | NO |  |
| PostalCode | `NVARCHAR(20)` | NO |  |
| IsDefault | `BIT` | NO | Default |

## Categories

| Column | Type | Nullable | Notes |
|---|---|---|---|
| CategoryID | `INT` | NO | Identity, PK |
| CategoryName | `NVARCHAR(100)` | NO | Unique |
| ParentCategoryID | `INT` | YES | FK |

## Products

| Column | Type | Nullable | Notes |
|---|---|---|---|
| ProductID | `INT` | NO | Identity, PK |
| SKU | `VARCHAR(40)` | NO | Unique |
| CategoryID | `INT` | NO | FK |
| ProductName | `NVARCHAR(160)` | NO |  |
| UnitPriceEUR | `DECIMAL(12,2)` | NO | Check |
| UnitCostEUR | `DECIMAL(12,2)` | NO | Check |
| ReorderPoint | `INT` | NO | Check |
| ReorderQuantity | `INT` | NO | Check |
| IsActive | `BIT` | NO | Default |

## Suppliers

| Column | Type | Nullable | Notes |
|---|---|---|---|
| SupplierID | `INT` | NO | Identity, PK |
| CountryID | `TINYINT` | NO | FK |
| SupplierCode | `VARCHAR(20)` | NO | Unique |
| SupplierName | `NVARCHAR(150)` | NO |  |
| DefaultLeadDays | `INT` | NO | Check |
| IsActive | `BIT` | NO | Default |

## SupplierProducts

| Column | Type | Nullable | Notes |
|---|---|---|---|
| SupplierID | `INT` | NO | FK |
| ProductID | `INT` | NO | FK |
| ContractUnitCostEUR | `DECIMAL(12,2)` | NO | Check |
| MinimumOrderQty | `INT` | NO | Check |

## Inventory

| Column | Type | Nullable | Notes |
|---|---|---|---|
| WarehouseID | `INT` | NO | FK |
| ProductID | `INT` | NO | FK |
| QuantityOnHand | `INT` | NO | Default |
| QuantityReserved | `INT` | NO | Default |

## InventoryMovements

| Column | Type | Nullable | Notes |
|---|---|---|---|
| MovementID | `BIGINT` | NO | Identity, PK |
| WarehouseID | `INT` | NO |  |
| ProductID | `INT` | NO |  |
| QuantityDelta | `INT` | NO | Check |
| MovementType | `VARCHAR(20)` | NO | Check |
| ReferenceType | `VARCHAR(30)` | YES |  |
| ReferenceID | `BIGINT` | YES |  |

## SalesOrders

| Column | Type | Nullable | Notes |
|---|---|---|---|
| OrderID | `BIGINT` | NO | Identity, PK |
| OrderNumber | `VARCHAR(40)` | NO | Unique |
| ExternalRequestKey | `VARCHAR(80)` | YES |  |
| CustomerID | `INT` | NO | FK |
| ShipAddressID | `INT` | NO | FK |
| StoreID | `INT` | YES | FK |
| SalesChannel | `VARCHAR(10)` | NO | Check |
| OrderStatus | `VARCHAR(12)` | NO | Check |

## SalesOrderItems

| Column | Type | Nullable | Notes |
|---|---|---|---|
| OrderItemID | `BIGINT` | NO | Identity, PK |
| OrderID | `BIGINT` | NO | FK |
| ProductID | `INT` | NO | FK |
| Quantity | `INT` | NO | Check |
| UnitPriceEUR | `DECIMAL(12,2)` | NO | Check |
| UnitCostEUR | `DECIMAL(12,2)` | NO | Check |

## InventoryReservations

| Column | Type | Nullable | Notes |
|---|---|---|---|
| ReservationID | `BIGINT` | NO | Identity, PK |
| OrderItemID | `BIGINT` | NO | FK |
| WarehouseID | `INT` | NO | FK |
| Quantity | `INT` | NO | Check |
| ReservationStatus | `VARCHAR(10)` | NO | Check |

## OrderFulfillments

| Column | Type | Nullable | Notes |
|---|---|---|---|
| FulfillmentID | `BIGINT` | NO | Identity, PK |
| OrderID | `BIGINT` | NO | FK |
| WarehouseID | `INT` | NO | FK |
| FulfillmentStatus | `VARCHAR(12)` | NO | Check |

## FulfillmentItems

| Column | Type | Nullable | Notes |
|---|---|---|---|
| FulfillmentItemID | `BIGINT` | NO | Identity, PK |
| FulfillmentID | `BIGINT` | NO | FK |
| OrderItemID | `BIGINT` | NO | FK |
| Quantity | `INT` | NO | Check |

## Carriers

| Column | Type | Nullable | Notes |
|---|---|---|---|
| CarrierID | `SMALLINT` | NO | Identity, PK |
| CarrierName | `NVARCHAR(100)` | NO | Unique |
| StandardDeliveryDays | `INT` | NO | Check |

## Shipments

| Column | Type | Nullable | Notes |
|---|---|---|---|
| ShipmentID | `BIGINT` | NO | Identity, PK |
| FulfillmentID | `BIGINT` | NO | FK |
| CarrierID | `SMALLINT` | NO | FK |
| TrackingNumber | `VARCHAR(60)` | NO | Unique |
| ShipmentStatus | `VARCHAR(12)` | NO | Check |

## PurchaseOrders

| Column | Type | Nullable | Notes |
|---|---|---|---|
| PurchaseOrderID | `BIGINT` | NO | Identity, PK |
| SupplierID | `INT` | NO | FK |
| WarehouseID | `INT` | NO | FK |
| PurchaseOrderNumber | `VARCHAR(40)` | NO | Unique |
| PurchaseStatus | `VARCHAR(12)` | NO | Check |

## PurchaseOrderItems

| Column | Type | Nullable | Notes |
|---|---|---|---|
| PurchaseOrderItemID | `BIGINT` | NO | Identity, PK |
| PurchaseOrderID | `BIGINT` | NO | FK |
| ProductID | `INT` | NO | FK |
| QuantityOrdered | `INT` | NO | Check |
| UnitCostEUR | `DECIMAL(12,2)` | NO | Check |

## GoodsReceipts

| Column | Type | Nullable | Notes |
|---|---|---|---|
| GoodsReceiptID | `BIGINT` | NO | Identity, PK |
| PurchaseOrderItemID | `BIGINT` | NO | FK |
| QuantityReceived | `INT` | NO | Check |
| ReceiptReference | `VARCHAR(80)` | NO | Unique |

## ReturnRequests

| Column | Type | Nullable | Notes |
|---|---|---|---|
| ReturnID | `BIGINT` | NO | Identity, PK |
| OrderID | `BIGINT` | NO | FK |
| ReturnStatus | `VARCHAR(12)` | NO | Check |

## ReturnItems

| Column | Type | Nullable | Notes |
|---|---|---|---|
| ReturnItemID | `BIGINT` | NO | Identity, PK |
| ReturnID | `BIGINT` | NO | FK |
| OrderItemID | `BIGINT` | NO | FK |
| Quantity | `INT` | NO | Check |
| Disposition | `VARCHAR(8)` | NO | Check |

## AuditEvents

| Column | Type | Nullable | Notes |
|---|---|---|---|
| AuditEventID | `BIGINT` | NO | Identity, PK |
| EventType | `VARCHAR(60)` | NO |  |
| EntityType | `VARCHAR(40)` | NO |  |
| EntityID | `BIGINT` | NO |  |
