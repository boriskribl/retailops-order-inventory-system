# CV and GitHub positioning — use only after verification

## Suggested GitHub repository name

`retailops-business-system-analysis-sql-server`

## CV project entry (only when SQL scripts and tests have actually run)

**RetailOps — Enterprise Order & Inventory Management System**  
*Microsoft SQL Server, Business/System Analysis, BPMN/UML, Power BI*

- Developed a fictional end-to-end retail operations case study, defining business requirements, user stories, acceptance criteria and traceability across a multi-country inventory and order management workflow.
- Designed a 25-table SQL Server schema and implemented transactional stock allocation, warehouse-scoped fulfillment, order lifecycle, procurement/return handling and analytical views.
- Prepared SQL integration and concurrency tests, query-performance study and a three-page Power BI reporting model, linking technical rules to operational KPIs.

**Do not** claim measured performance gains, passed concurrency tests or a deployed Power BI dashboard until you have evidence.

## Short GitHub About description

> Business/System Analyst portfolio: stakeholder requirements, BPMN/UML, 25-table SQL Server design, atomic stock allocation, synthetic retail data, SQL tests and Power BI build kit.

## 30-second recruiter pitch

> “I built a fictional multi-country retail order and inventory case to demonstrate the full analyst workflow. I documented business pain points, translated them into user stories and testable requirements, modeled current and future processes, then designed and implemented SQL business rules around warehouse stock reservations. The project also includes data-quality tests and a KPI reporting model, so each business requirement has a traceable technical implementation.”

## Interview preparation checklist

- [ ] Explain FR-03 and why all-or-nothing reservation was selected.
- [ ] Show at least one SQL transaction and explain `UPDLOCK`, `HOLDLOCK` and rollback.
- [ ] Understand order/fulfillment/reservation cardinalities on the ERD.
- [ ] Run tests in SSMS and save your results, including negative stock checks.
- [ ] Know the BI fact grain and why order count is distinct.
- [ ] Explain three limitations (FX, payments, RBAC) and their production solution.
- [ ] Do not imply this case was done for Grid Dynamics or an actual paying client.
