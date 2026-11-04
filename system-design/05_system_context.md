# System context and data flows

```mermaid
flowchart TB
    Customer[Customer / support agent] --> OrderRequest[Order request - conceptual API]
    POS[Physical store] --> OrderRequest
    OrderRequest --> DB[(RetailOpsDB - SQL Server)]
    Warehouse[Warehouse operator] --> DB
    Supplier[Supplier / buyer] --> DB
    Carrier[Courier agent] --> DB
    DB --> Views[Five analytical views]
    Views --> BI[Power BI Desktop - manual setup]
    BI --> Leaders[Finance / Operations decision makers]
    DBA[QA / DBA] --> Tests[SQL integrity + performance tests]
    Tests --> DB
```

## Logical data flow

1. **Order payload** → SalesOrders, SalesOrderItems; customer and address checked.
2. **Allocation** → Inventory.QuantityReserved, InventoryReservations, OrderFulfillments, FulfillmentItems.
3. **Dispatch** → Inventory.QuantityOnHand, InventoryMovements, Shipments.
4. **Delivery** → Shipments status and OrderFulfillments/SalesOrders state.
5. **Procurement** → PurchaseOrders / GoodsReceipts / InventoryMovements.
6. **Returns** → ReturnRequests / ReturnItems / InventoryMovements.
7. **Insight** → views → Power BI.

Physical system is only SQL Server and its SQL scripts; arrows from external actors show *intended interactions*, not implemented integrations.
