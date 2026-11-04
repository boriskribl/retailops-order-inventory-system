# SOFTWARE / SYSTEM REQUIREMENTS SPECIFICATION (SRS)

**System:** RetailOps v1.0 | **Database:** Microsoft SQL Server (T-SQL) | **Audience:** BA, system analyst, DBA, QA, reporting analyst  
**Artifact type:** Portfolio system specification — not a deployed application.

## 1. System purpose and boundaries

RetailOps models the write-side workflows and reporting-side semantics for a fictional multi-market retail organization. SQL Server is the system of record for orders, inventory, fulfillment, procurement, and returns. The prototype has **no user interface, API server or payment system**; SSMS procedure calls simulate an external service layer. Views expose read-only semantic data for Power BI.

### 1.1 Actors

- **Sales channel / customer service:** request validated order creation and idempotent retry.
- **Inventory allocation service:** reserve available stock in domestic-first order.
- **Warehouse operator:** dispatch picking units, trigger ledger movement and shipment record.
- **Carrier / support staff:** confirm delivery timestamps.
- **Procurement specialist:** receive items against approved purchase orders.
- **Returns specialist:** receive an approved return and select processing warehouse.
- **Operations analyst / BI:** read KPI views with read-only permissions.
- **DBA / QA:** test constraints, indices, and ledger reconciliation.

## 2. Component architecture

```
+--------------------------+
| Channels (not built)     |
| E-commerce / POS / agent |
+-------------+------------+
              | proposed service/API boundary
              v
+--------------------------+
| SQL Server - RetailOpsDB |
| Validation + procedures  |
| 25-table relational core |
| Inventory movement log   |
+-------------+------------+
              | reporting views
              v
+--------------------------+
| Power BI (manual setup)  |
| 3-page design + DAX/M    |
+--------------------------+
```

No application executable, background job, scheduler or hosted data service is included. The SQL procedures are demonstration endpoints.

## 3. Functional requirements

| Req | Description | Procedure / view | Validation / result |
|---|---|---|---|
| FR-01 | Create new order and deduplicate repeated external key | usp_CreateOrder | Address owner / active products / JSON schema / idempotency |
| FR-02 | Normalize order lines | usp_CreateOrder | Group duplicate ProductIDs; immutable snapshot of price and cost |
| FR-03 | Reserve enough units across stock pools, atomically | usp_AllocateOrder | `UPDLOCK,HOLDLOCK`; failure rolls back full allocation |
| FR-04 | Rank domestic warehouse first, split if necessary | usp_AllocateOrder | Country matching; higher available balance breaks ties |
| FR-05 | Release stock for pre-dispatch canceled orders | usp_CancelOrder | Only NEW/RESERVED; status changes and active holds released |
| FR-06 | Dispatch picking fulfillment, capture delivery | usp_DispatchFulfillment; usp_MarkShipmentDelivered | Reservation→CONSUMED; movement SALE; shipment state transitions |
| FR-07 | Prevent excess PO receipts and record arrival | usp_ReceivePurchaseOrderItem | Approved/partial PO, qty <= outstanding; receipt movements |
| FR-08 | Receive approved returns | usp_ReceiveReturn | Delivered order, ordered qty bound, RESTOCK vs SCRAP |
| FR-09 | Capture operational history | InventoryMovements and AuditEvents | References to changed entity and timestamp |
| FR-10 | Standardize executive and operational reporting | 5 SQL views | Defined grain and KPI formulas |
| FR-11 | Flag reorder requirements | vw_InventoryHealth | AvailableQty <= ReorderPoint |

## 4. State machines

### SalesOrders

| From | Event | To | Guard |
|---|---|---|---|
| (new record) | CreateOrder | NEW | valid customer/address/items |
| NEW | AllocateOrder | RESERVED | sufficient stock across eligible warehouses |
| NEW / RESERVED | CancelOrder | CANCELLED | no dispatch |
| RESERVED | Dispatch one of several fulfillments | PARTIAL | another fulfillment still PICKING |
| RESERVED / PARTIAL | Dispatch last picking fulfillment | SHIPPED | none remains PICKING |
| PARTIAL / SHIPPED | MarkShipmentDelivered | PARTIAL / SHIPPED / DELIVERED | all fulfillments DELIVERED => DELIVERED |

### InventoryReservations

ACTIVE → CONSUMED (upon dispatch) or ACTIVE → RELEASED (pre-dispatch cancellation). Historic seed reservations are already CONSUMED.

### Shipments

IN_TRANSIT → DELIVERED; LOST is supported by schema as a future exception state but no procedure enters LOST in this prototype.

### PurchaseOrders

DRAFT → APPROVED (manual setup outside procedure) → PARTIAL → RECEIVED. Note: PO creation/approval UI or approval procedure is deferred.

### Returns

REQUESTED → APPROVED (manual review not automated) → RECEIVED; REJECTED exists but no validation procedure for rejection. **Only APPROVED → RECEIVED is implemented** as a transactional workflow.

## 5. Interface contract (stored procedure boundary)

### usp_CreateOrder

**Inputs:** `CustomerID INT, ShipAddressID INT, SalesChannel VARCHAR(10), ItemsJson NVARCHAR(MAX), StoreID INT optional, ExternalRequestKey VARCHAR(80) optional`  
**Output:** `OrderID BIGINT OUTPUT`.

```sql
DECLARE @NewOrderID BIGINT;
EXEC dbo.usp_CreateOrder
  @CustomerID=1,
  @ShipAddressID=1, -- replace with address belonging to this customer
  @SalesChannel='ONLINE',
  @ItemsJson=N'[{"ProductID":1,"Quantity":2},{"ProductID":2,"Quantity":1}]',
  @ExternalRequestKey='REQUEST-2026-0001',
  @OrderID=@NewOrderID OUTPUT;
SELECT @NewOrderID AS NewOrderID;
```

**Response behavior:** invalid payload raises custom 510xx SQL error and rolls back; duplicate external request key returns the original ID **only when the normalized payload and order metadata match**. Idempotency compares the normalized product/quantity lines and the customer/address/channel/store fields. A reused key with different request content is rejected with error 51009. It does not store a cryptographic payload hash.

### usp_AllocateOrder

Input `@OrderID BIGINT`. In one transaction, acquire update/serializable locks, choose domestic warehouses where possible, reserve entire order; throws 51102 and rolls back on insufficient stock.

### usp_DispatchFulfillment

Inputs `FulfillmentID`, `CarrierID`, optional `TrackingNumber`. Output `ShipmentID`. Precondition active matching reservation; after success on-hand and reserved decrease, ledger is written, shipment is IN_TRANSIT.

### usp_MarkShipmentDelivered

Inputs `ShipmentID`, optional `DeliveredAt` UTC. Timestamp must not precede shipment. The parent order reaches DELIVERED only after all fulfillment shipments complete.

### usp_CancelOrder

Input `OrderID`. NEW/RESERVED only. No inventory movement row is written because stock was not physically removed; `QuantityReserved` decreases.

### usp_ReceivePurchaseOrderItem

Inputs `PurchaseOrderItemID`, `Quantity`, globally unique `ReceiptReference`. Records partial or full receipt, changes PO status and on-hand quantity.

### usp_ReceiveReturn

Inputs `ReturnID`, `ProcessingWarehouseID`. For an APPROVED return from a DELIVERED order, RESTOCK increases available stock in designated warehouse. SCRAP leaves stock unchanged. Duplicate receipt rejected.

## 6. Core relational model / integrity rules

- `(WarehouseID,ProductID)` is unique in Inventory; CHECK: `0 <= reserved <= on-hand`.
- Order items have unique `(OrderID,ProductID)`; reservations unique `(OrderItemID,WarehouseID)`.
- Fulfillments unique `(OrderID,WarehouseID)`; one shipment per fulfillment.
- Orders keep price and cost at order time to avoid changing historic results when the catalog changes.
- Status enumerations and positive quantities validated with CHECK constraints.
- Each receipt has a unique external reference to prevent duplicate entries.
- All operational mutations must use procedures for business-level invariants. Direct writes bypass procedural validation and should be permission-restricted in a real deployment.

## 7. Allocation algorithm (FR-03/FR-04)

```text
BEGIN TRANSACTION
  Lock order; require status NEW
  For each order line, ordered by ProductID:
    remaining = requested units
    While remaining > 0:
      Lock a warehouse/Product inventory row (UPDLOCK, HOLDLOCK), ranked by:
        1. country matches destination
        2. most available units
        3. warehouse ID
      If no row has available units: THROW; ROLLBACK WHOLE ORDER
      Take min(remaining, available)
      Increment reserved quantity, insert ACTIVE reservation,
      insert/create warehouse fulfillment and fulfillment item
      remaining -= take
  Set order RESERVED
COMMIT
```

**Concurrency notes:** Cross-item allocation can still face deadlocks at scale. A production service would retry SQL error 1205 with jitter and use more precise lock/load testing. The prototype's key guarantee is no committed overselling under its prescribed procedure, not zero transient retries.

## 8. Nonfunctional requirements and evidence

| ID | Requirement | Evidence and validation status |
|---|---|---|
| NFR-01 | Declarative integrity | Schema CHECK, FK, UQ; local validation V01–V06 passed and optimized V07 returned MismatchCount=0 |
| NFR-02 | Atomic stock writes | TRY/CATCH, XACT_ABORT, transactions and locks; local two-session C01 observed expected rejection (SQL 51102) |
| NFR-03 | Measurable reporting query performance | Targeted indexes + timing observations: 479 ms initial, 439 ms follow-up, 1,975 logical reads both; no measured optimization claimed |
| NFR-04 | Privacy and access control | Synthetic data; GRANT/DENY and credential layer are deployment gaps |
| NFR-05 | Operational recoverability | Scripts are ordered, idempotency for order insert; backups not implemented |
| NFR-06 | Lineage | Requirement IDs, test IDs, schema diagram, SQL view names, GitHub READMEs |

## 9. Test strategy

Integration tests **T01–T08** and expected-failure tests **N01–N03** passed in reported local SQL Server execution. Manual two-session C01 rejected a competing allocation with expected SQL error `51102`. Post-install V01–V06 passed and a separate optimized V07 returned `MismatchCount = 0`. The three-page Power BI Desktop `.pbix` was built and locally refreshed. These results are evidence from an educational demo, **not independently replicated CI or production validation**.

## 10. Limitations and design debt

1. Inventory balances use current snapshot plus transaction ledger. Historic stock was synthesized and does not emulate a real receiving chronology beyond the demo rules.
2. Source currencies, exchange rates, VAT, refunds, cash collection and shipping fees are not modeled.
3. No external system integration, identity layer, row-level security or access policies are configured.
4. Supplier approval and return approval are represented as modeled states and direct seed records, not as implemented actor workflows.
5. No dedicated order-item partial shipment retry/reallocation flow after a warehouse has dispatched.
6. Current-state process and business targets are fictional proposals; no stakeholder interviews occurred.
7. A three-page Power BI Desktop `.pbix` and screenshots are included. Reproducing refresh requires a separately configured local SQL Server instance and synthetic demo data.

## 11. Decision log

| ID | Decision | Tradeoff |
|---|---|---|
| ADR-01 | SQL Server over MySQL | Fits user's SSMS setup and procedure transaction demonstrations |
| ADR-02 | EUR standard demo | Simple comparisons, but not financial-grade for Serbia |
| ADR-03 | All-or-nothing stock allocation | Correctness/simple acceptance; no backorders |
| ADR-04 | Warehouse-scoped fulfillment | Represents split shipping; no cross-border cost optimization |
| ADR-05 | Import BI views | Local three-page Power BI report is built; refresh still requires a configured local SQL Server |
| ADR-06 | No frontend | BA/SA scope and technical depth prioritized over UI presentation |
