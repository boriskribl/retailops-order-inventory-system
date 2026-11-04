# Order lifecycle — UML sequence diagram

```mermaid
sequenceDiagram
    autonumber
    actor Sales as Sales channel / Agent
    participant Orders as SQL: Orders service
    participant Inv as SQL: Inventory
    participant Warehouse as Warehouse operator
    participant Courier as Carrier interface (manual)
    participant BI as Power BI views
    Sales->>Orders: usp_CreateOrder(customer, address, lines, key)
    Orders-->>Sales: OrderID (NEW)
    Sales->>Orders: usp_AllocateOrder(OrderID)
    loop For each line, possibly across warehouses
      Orders->>Inv: Lock Inventory (UPDLOCK, HOLDLOCK)
      alt Available stock
        Inv-->>Orders: available > 0
        Orders->>Inv: reserved += allocated units
      else No more stock
        Inv-->>Orders: insufficient stock
        Orders-->>Sales: error 51102 + ROLLBACK
      end
    end
    Orders-->>Sales: RESERVED + fulfillment IDs
    Warehouse->>Orders: usp_DispatchFulfillment(FulfillmentID)
    Orders->>Inv: on-hand -= qty; reserved -= qty
    Orders-->>Warehouse: ShipmentID (IN_TRANSIT)
    Courier->>Orders: usp_MarkShipmentDelivered(ShipmentID)
    Orders-->>Courier: DELIVERED
    BI->>Orders: read reporting views
    Orders-->>BI: order/stock/fulfillment facts
```

**Separation of responsibilities:** In a production application, Sales/Warehouse/Courier would call a service API with authentication, not access SQL procedures directly. The sequence above demonstrates backend behavior only.
