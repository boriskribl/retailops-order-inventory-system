# BUSINESS REQUIREMENTS DOCUMENT (BRD)

**RetailOps — Enterprise Order & Inventory Management**  
**Version:** 1.0 | **Classification:** Portfolio simulation | **Status:** Proposed solution  
**Prepared for:** Hypothetical multinational retail client | **Region:** Serbia, Croatia, Slovenia  
**Document owner:** Business Analysis | **Currency convention:** EUR-equivalent reporting, no live FX  

> **Important:** All company data, stakeholders, findings, targets and business processes in this project are fictional. Business targets below are hypotheses and proposed acceptance targets, not measured customer achievements.

## 1. Executive summary

RetailOps is a proposed order and warehouse inventory solution for a mid-sized omnichannel retailer with six distribution centers and stores across three Southeast European countries. The current-state narrative assumes fragmented stock visibility, manual allocation, late shipments, and inconsistent management reporting. The initiative centralizes order, reservation, fulfillment, purchasing, return and audit records and exposes a reproducible analytical model.

**Decision requested:** Approve a discovery-to-prototype initiative validating stock reservation accuracy, regional warehouse routing, order traceability, and operational KPI reporting. No real deployment is proposed.

## 2. Business problem and opportunity

| ID | Hypothetical pain point | Business implication | Proposed capability |
|---|---|---|---|
| BP-01 | Sales channels cannot reliably see live available-to-promise stock | Overselling / cancelations / poor customer experience | Central inventory ledger and atomic reservations |
| BP-02 | Teams manually choose warehouses | Missed domestic fulfillment opportunities | Domestic-first, multi-warehouse allocation |
| BP-03 | Shipments, expected dates, and actual arrival dates lack a unified record | Late delivery not systematically identified | Shipment events and SLA performance |
| BP-04 | Procurement and stock replenishment are reactive | Stockouts and idle capital | Reorder thresholds and receipt tracking |
| BP-05 | Returns and canceled orders are reconciled manually | Inaccurate inventory and margin | Controlled cancellations, returns, and movement history |
| BP-06 | Reporting combines incompatible spreadsheet definitions | Decisions based on inconsistent revenue/return measures | Defined views, KPI dictionary, Power BI model |

## 3. Business objectives and proposed success criteria

| Objective | Proposed KPI | Proposed pilot acceptance target | Measurement |
|---|---|---|---|
| No overselling | Invalid negative available stock incidents | 0 in predefined tests | T-SQL integration/concurrency tests |
| Accurate reservation | Difference between active reservations and reserved quantity | 0 units | Reconciliation query T06 |
| Traceable processing | Fulfilled lines with complete order-to-shipment lineage | 100% of test-case fulfilled lines | Traceability queries |
| Improved visibility | Critical dashboards sourced from a documented semantic model | 3 report pages, defined measures | Power BI acceptance checklist |
| Transparent exception handling | Failed allocation leaves no partial stock reservation | 100% of tested failure cases | N01 and C01 |
| Earlier replenishment | SKUs under reorder point flagged | All test-case low-stock SKUs | Inventory Health view |

These are **proposed acceptance criteria**, not observed improvements. The synthetic data cannot establish causal operational ROI.

## 4. Stakeholders / stakeholder analysis

| Stakeholder | Primary need | Decision rights | Engagement |
|---|---|---|---|
| Head of Operations (Sponsor) | Reliable order cycle and service level | Budget and priority | Weekly decision review |
| Warehouse Manager | Reservation, picking, availability | Operational acceptance | Scenario workshops |
| E-commerce Product Owner | Stable stock promise and status | Product scope | Backlog refinement |
| Procurement Lead | Reorder suggestions and receipts | Purchasing rules | Acceptance walkthrough |
| Finance Analyst | Consistent net revenue and margin | KPI sign-off | Data definition review |
| Customer Support Lead | Order and return traceability | Service requirements | User-story review |
| Engineering Lead / DBA | Correct transactions, schema, performance | Technical design | Design review |
| Privacy/Compliance Officer | Data minimization / retention | Compliance assessment | Security checkpoint |

## 5. Scope

**In scope (portfolio prototype)**

- Three countries, six warehouses, six stores, products, customers, suppliers, inventory balances.
- Online/store order intake, immutable line price/cost snapshots, idempotency key option.
- Atomic multi-warehouse allocation, order lifecycle, cancellation before shipment.
- Dispatch/delivery tracking, purchasing receipts, approved returns and restocking.
- Audit event log, inventory movement reconciliation, SQL analytical views, BI preparation.
- Analyst artifacts: requirements, stakeholder map, user stories, process diagrams, acceptance tests, traceability.

**Out of scope (explicit limits)**

- Live payment gateways, tax/VAT calculations, invoices, live courier APIs, POS and e-commerce user interfaces.
- Optimized routing by geospatial distance, shipping cost or promised delivery SLAs.
- Multi-currency conversion or accounting-grade revenue recognition.
- Authentication/authorization system, personally identifiable production data, deployment pipeline.
- Real ERP integration, returns authorization UI, capacity/weight optimization.

## 6. Process outline — current vs future

**Assumed current state:** Store/web request → employee checks local inventory → ad hoc emails to other warehouses → manual hold spreadsheet → shipment record in courier portal → weekly reporting spreadsheet. Each handoff may cause delays or inconsistent counts.

**Proposed future state:** Channel creates validated order → system finds domestic warehouse then regional alternatives → locks and atomically reserves inventory (or fully rolls back) → picking by warehouse → stock movement and shipment tracking → delivered/overdue monitoring → return/replenishment workflows → dashboards.

See `system-design/02_process_to_be.bpmn` and `system-design/03_process_current_state.md`.

## 7. Business rules

| Rule | Description |
|---|---|
| BR-01 | Available stock = on-hand minus active reserved quantity; must never be negative. |
| BR-02 | Allocation prioritizes warehouses in destination country, then higher available quantity. |
| BR-03 | If aggregate reachable stock is insufficient, all allocation changes are rolled back. |
| BR-04 | A line may be split across multiple warehouses; each fulfillment remains warehouse-scoped. |
| BR-05 | Cancellation is permitted for NEW or RESERVED orders only; released stock remains physically on hand. |
| BR-06 | Physical stock is reduced on shipment dispatch, not at order creation or allocation. |
| BR-07 | Goods receipts cannot exceed ordered quantities; receiving increments available physical stock. |
| BR-08 | Approved return receipt adds physical stock only for RESTOCK disposition; SCRAP does not. |
| BR-09 | Recognized demo revenue is counted when order status = DELIVERED; received returns reduce net revenue. |
| BR-10 | The demo treats sales prices and costs as EUR-denominated across markets; regional currency conversion is outside scope. |
| BR-11 | Customer shipping address must belong to that customer. |
| BR-12 | A repeated request key returns the original order, avoiding duplicated insertion; payload mismatch detection is deferred. |

## 8. Nonfunctional expectations

- **Data integrity:** PK/FK, check constraints, audit trail, ledger reconciliation.
- **Concurrency:** last-unit stock scenario tested with two query windows; retry deadlocks at integration layer.
- **Performance:** instrument representative indexed queries with actual query plans and `STATISTICS IO/TIME`; do not claim unmeasured performance gains.
- **Security (deployment gap):** use least-privilege database roles, encryption and secrets management before external use. Sample customers use `example.invalid` and contain no actual PII.
- **Observability:** SQL error numbers, audit events, validation scripts, execution log.
- **Maintainability:** ordered scripts, English docs, stable names, small procedures with defined responsibilities.

## 9. Risks and dependencies

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Incorrect available-stock logic | Medium / High | Serialized allocation and ledger checks |
| Requirements misunderstood | Medium / Medium | User stories and explicit acceptance criteria |
| Analytics double-count orders | Medium / High | Define fact grain; DISTINCTCOUNT at order level |
| Regional reporting conflates currencies | High / High in production | Explicit EUR-only prototype assumption; add FX service in real project |
| SQL Express hardware bottleneck | Medium / Medium | Batch data load, then indexes; scale dataset down if required |
| Synthetic trends mistaken for real findings | Medium / High | Label fictional data and avoid outcome claims |
| Returns workflow bypassed by manual direct table writes | Medium / High | Controlled procedures; deployment permissions needed |

## 10. Deliverables and sign-off

A prototype is accepted when the schema installs cleanly, seeded data loads, expected automated checks pass on the intended instance, order-to-delivery/return scenarios are demonstrable, and business metrics are documented. Proposed owners for sign-off: Operations Sponsor (business), Engineering Lead (technical), Finance Analyst (metrics). No real-world stakeholder sign-off has occurred.

## 11. Change requests for a second iteration

CR-01 Cross-border allocation with shipping cost + SLA optimization; CR-02 true currency translation / VAT; CR-03 role access and API; CR-04 backorder and partial stock reservations; CR-05 source-to-target incremental ETL and BI refresh; CR-06 warehouse capacity and purchase lead-time prediction.
