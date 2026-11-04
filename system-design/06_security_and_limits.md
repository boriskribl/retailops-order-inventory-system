# Security, data quality, assumptions, and production gap checklist

This is a **local learning prototype**, not a production-ready enterprise implementation.

## Data quality and integrity

- Synthetic names and emails with `@example.invalid` are used; no actual customer records.
- SQL constraints establish unique product codes, customer emails, addresses, positive quantities and FK linkage.
- Historical test data is fabricated with a deterministic arithmetic pattern and intentionally weighted seasonal dates; patterns are not empirical findings.
- All operational writes should be executed through procedures. Direct table writes can circumvent transaction-level business rules.

## Security gaps before any deployment

- Define `CREATE ROLE` / least-privilege `GRANT EXECUTE` and reporting `GRANT SELECT`; disallow direct table modification.
- Add database service identity, secrets rotation, encrypted connection and server certificate validation; the SSMS local demo may use trust-server-certificate for development only.
- Introduce personal data lifecycle, deletion/anonymization, consent/legal basis, access logs, retention and jurisdiction-specific review.
- Add an authenticated API, input schema validation at boundary, rate limiting, audit ownership, backup/restore and monitoring.
- Conduct penetration/security testing and data-protection review. Not done in this project.

## Performance and concurrency gaps

- No actual SQL Server benchmark or execution plans have been captured by the generator.
- The 100k order seed is a demonstration data volume, not production load or proof of scalability.
- Cross-warehouse parallel allocations can deadlock; production callers would handle retry (error 1205) with bounded exponential backoff.
- No stress harness or deadlock graph capture is bundled; a manual two-session test protocol is included.

## Next iteration architecture

Introduce API boundary, RBAC, outbox/CDC for BI synchronization, versioned DDL migrations, external carrier/payment integrations, price+tax+FX services, source system reconciliation and cloud-based observability.
