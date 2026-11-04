# Product backlog, user stories and acceptance criteria

**Format:** `As a [stakeholder], I want [capability] so that [benefit].` Priority uses MoSCoW for a prototype, not an official client backlog.

## Epic A — Order capture

**US-01 | Must | Customer service agent**  
As an agent, I want to create an order with valid products and address so that a customer request has a traceable ID.

- **Given** a registered customer and one of their own addresses, **when** a valid JSON line list is submitted, **then** an order in NEW state is created with price and cost snapshots.
- Given a customer and another customer's address, when submitted, then error 51004 is returned and no order is created.
- Given the same `ExternalRequestKey` twice with identical normalized content, the original `OrderID` is returned. Given the same key with different items or other request metadata, error 51009 is returned and the original order remains unchanged (N03).

**US-02 | Must | E-commerce Product Owner**  
As an owner, I want duplicate product lines combined so that an order has one normalized line per product.

- Given repeated ProductID entries, then stored quantity is the sum and `(OrderID,ProductID)` is unique.
- Quantity must be positive; inactive or unknown products are rejected.

## Epic B — Inventory control

**US-03 | Must | Warehouse Manager**  
As a warehouse manager, I want stock allocated atomically so that two customers cannot reserve the same last unit.

- Given enough available units, when allocation runs, then active reservations match total ordered units and order becomes RESERVED.
- Given less total available stock than requested, when allocation runs, then no reservation, fulfillment or on-hand update remains after the error.
- Given two overlapping allocations for the same last unit, at most one can succeed; any deadlock requires retry.

**US-04 | Must | Logistics Lead**  
As a lead, I want the system to prefer a local warehouse and support a split, so that sales can use regional stock.

- When domestic stock is available, domestic candidates are ranked ahead of foreign candidates.
- When one warehouse cannot cover a line, remaining quantity is allocated from another warehouse; complete order remains all-or-nothing.
- Each warehouse has its own fulfillment record.

**US-05 | Must | Support Agent**  
As a support agent, I want to cancel unshipped orders so that reserved stock returns to availability.

- Given NEW or RESERVED, cancel changes order to CANCELLED and releases any active reservations.
- Given PARTIAL or SHIPPED, cancellation is rejected and no stock changes are made.

## Epic C — Fulfillment

**US-06 | Must | Warehouse Operator**  
As an operator, I want dispatch to decrement on-hand only after successful picking so that physical stock matches movements.

- Given PICKING fulfillment with active matching reservation, dispatch creates one shipment with an expected date; reservation becomes CONSUMED.
- On-hand and reserved both decrease by dispatched quantity, and one or more SALE ledger rows are inserted.
- Given an invalid carrier, dispatch is rejected without a partial shipment.

**US-07 | Must | Customer Support Lead**  
As a lead, I want actual delivered time captured so that lateness is quantifiable.

- Given an IN_TRANSIT shipment and a valid delivery timestamp, status becomes DELIVERED.
- The order becomes DELIVERED only after *every* fulfillment is delivered.
- On-time means `DeliveredAt <= ExpectedDeliveryAt`.

## Epic D — Procurement and returns

**US-08 | Must | Procurement Lead**  
As a buyer, I want to receive a PO line in increments so that stock balances reflect partial deliveries.

- A receipt in APPROVED/PARTIAL state increments on-hand and writes RECEIPT movement.
- A receipt larger than outstanding quantity returns error 51502.
- All items fully received => PO status RECEIVED; otherwise PARTIAL.

**US-09 | Must | Returns Team**  
As a returns specialist, I want approved returns processed once so that stock and refunds are consistent.

- Given an approved return for a delivered order, process each RESTOCK line into a designated processing warehouse.
- SCRAP lines do not increment stock. A processed return cannot be received again.
- Received returns reduce net demo sales revenue through the reporting view.

## Epic E — Insight and audit

**US-10 | Should | Operations Director**  
As a director, I want country revenue, margins, delivery timeliness and exceptions so that I can prioritize interventions.

- Dashboard measures have documented formula, report grain and qualifying statuses.
- Country slicers affect all applicable regional facts through a Country dimension.

**US-11 | Should | Inventory Planner**  
As a planner, I want reorder and slow-moving product reports so that I can adjust replenishment.

- Available stock at or below `ReorderPoint` is flagged REORDER.
- A product without SALE movement in the last 90 days may be flagged slow-moving, not necessarily obsolete.

**US-12 | Should | DBA / Auditor**  
As an auditor, I want the movement ledger to reconcile to current on-hand so that stock changes are explainable.

- Grouped movement deltas equal current on-hand by `(WarehouseID,ProductID)` after demo operations.
- Operational actions write audit events identifying entity and event type.

## Deferred stories (Could / Won't)

- **US-13 (Could):** Proactive replenishment based on forecast demand and lead times.
- **US-14 (Won't in prototype):** Payment authorization, tax, financial settlement and refund gateway.
- **US-15 (Won't in prototype):** Auto-selection by route distance, capacity, emissions or shipping price.

## Definition of done

Requirement linked to design + SQL module + test; no critical failed integrity checks; demo walkthrough is reproducible; any limitations and synthetic data assumptions are disclosed.
