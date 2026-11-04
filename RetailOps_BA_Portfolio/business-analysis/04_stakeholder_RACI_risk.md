# Stakeholder, RACI, scope and risk management

## RACI matrix — proposed client governance

| Activity | Sponsor | Product Owner | Business Analyst | Engineering Lead | QA | Finance |
|---|---|---|---|---|---|---|
| Frame business problem | A | C | R | C | I | C |
| Prioritize product scope | A | R | R | C | I | C |
| Define functional rules | I | A | R | C | C | C |
| Data architecture | I | C | C | A/R | C | C |
| SQL implementation | I | I | C | A/R | C | I |
| Acceptance testing | I | A | R | C | R | C |
| Revenue metric sign-off | I | C | R | C | I | A |
| Release / deployment decision | A | R | C | R | C | C |

`R = Responsible`, `A = Accountable`, `C = Consulted`, `I = Informed`. Role mapping is illustrative.

## Prioritization model

`Must`: order creation, reliable available-to-promise, reservation, dispatch, receiving, cancellation, returns, audit and basic accuracy.

`Should`: cross-country sales / procurement / SLA report, traceability, alert views.

`Could`: forecast replenishment, carrier selection optimization.

`Won't`: live payments, tax, multi-currency FX, mobile app or cloud deployment.

## Assumptions and open questions log

| ID | Assumption / question | Impact if wrong | Proposed owner |
|---|---|---|---|
| A-01 | All prices and costs stored in EUR reporting units | Real cross-country reconciliation would be invalid | Finance |
| A-02 | Orders can be fully reserved or rejected; no backorder | Partially available orders remain unfulfilled | Product Owner |
| A-03 | Selection prefers country then highest available stock | May raise freight/lead-time expense | Logistics |
| A-04 | One warehouse produces one fulfillment per order | Supports split picking but no reallocation after dispatch | Engineering |
| Q-01 | Is on-time based on promised date, customer-selected slot, or courier estimate? | KPI denominator & fairness | Operations |
| Q-02 | Are returns restocked to origin warehouse or dedicated returns center? | Warehouse inventory accuracy | Returns Lead |
| Q-03 | What tax, shipping and payment accounting rules apply? | Profit and revenue accuracy | Finance |
| Q-04 | What retention & access controls apply to customer data? | Privacy exposure | Compliance |

## RAID log

- **R-01:** Overselling under concurrency — **High**. Mitigation: row/update locks, check constraints, parallel test.
- **R-02:** Historical demo data mistaken for real KPIs — **High**. Mitigation: synthetic watermark and README disclosure.
- **A-01:** All prices in comparable EUR units — **High** if invalidated. Mitigation: proper FX service in phase 2.
- **I-01:** No live source systems to validate mappings — **Open**. Mitigation: requirements-led prototype, note unknowns.
- **D-01:** Availability of Microsoft SQL Server / SSMS — **Resolved for local setup** based on prior connection screenshot; execution on that host remains unverified.
