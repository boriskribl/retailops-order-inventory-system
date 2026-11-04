# Ten-minute Business/System Analyst project presentation

**Goal:** Communicate business value + traceability + SQL thinking, not recite 25 table names.

| Slide | Duration | What to communicate | Demo / evidence |
|---|---:|---|---|
| 1. Challenge | 45 sec | Multi-market retail operations need reliable available-to-promise and traceability | BRD BP-01–BP-06 |
| 2. Discovery & scope | 60 sec | Fictional stakeholders, business assumptions, in/out scope, proposed KPIs | BRD, RAID |
| 3. AS-IS → TO-BE | 60 sec | Fragmented manual process becomes order-to-dispatch workflow | BPMN XML, preview |
| 4. Requirements | 75 sec | FR-03 atomic allocation tied to acceptance and test N01/C01 | User story + RTM |
| 5. Technical design | 90 sec | Why 25 normalized tables / separate reservations vs on-hand | ERD, core constraints |
| 6. SQL business logic | 120 sec | Transactions + UPDLOCK/HOLDLOCK, all-or-nothing reservation, dispatch ledger | `usp_AllocateOrder` query snippet |
| 7. Insight / reporting | 75 sec | KPI grain, regional revenue, late deliveries, reorder warnings | Views and Power BI page plan |
| 8. Tests / tradeoffs | 75 sec | Failed allocations must leave no residue; prove tests and discuss gaps | T01–T08, C01, results after execution |
| 9. Reflection | 60 sec | What you would change: FX, API, RLS, cost-based routing, load testing | SRS decision log |

## Personal script (adapt with your own execution evidence)

> “This is a fictional but end-to-end business analysis case. I started with six operational pain points and mapped each one to measurable requirements and acceptance tests. Instead of developing a frontend, I prioritized the rules that make retail order management trustworthy: validated orders, atomic inventory reservations, traceable shipment transitions, controlled returns and procurement, and standardized KPIs.”

> “The hardest design choice was how to handle two orders attempting to reserve the same last unit. I used an atomic SQL transaction and locking on the stock row. If the full order cannot be reserved, the operation rolls back instead of keeping a partially reserved order. I would demonstrate this with two SSMS sessions and explain deadlock retry handling.”

> “My model separates physical stock from reserved stock: placing an order does not remove physical goods, dispatch does. I built a movement ledger, not only a stock snapshot, because inventory should be explainable later. I then created views at explicit grains so Power BI does not accidentally double-count orders.”

> “The synthetic dataset provides reproducible scenarios, not proof of a real operational improvement. For a real client my next step would be stakeholder interviews, baseline measurement, validating refund/FX/tax rules, and specifying API/security and integration contracts.”

## Questions you should be able to answer without reading slides

- Why did you choose all-or-nothing allocation instead of backorders?
- What is the difference between on-hand, reserved and available stock?
- Why does `UPDLOCK, HOLDLOCK` protect concurrent reservations; what can still deadlock?
- What does the data model normalize, and what snapshots deliberately denormalize?
- Why is revenue recognized only for delivered orders in your illustration?
- Why do you need DISTINCTCOUNT(OrderID) in Power BI?
- What would an SRS add beyond a BRD?
- How does a requirement connect to a test via the RTM?
- What production gaps would prevent real client deployment?

**Honesty requirement:** Never claim tests, optimization gains, dashboards, or business outcomes were personally run or measured until you actually run and inspect them. Be prepared to say you used AI-assisted drafting and explain how you validated the solution.
