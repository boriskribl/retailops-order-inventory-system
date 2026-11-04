# RetailOps v1.7 — T01 SQL ispravka

Uzrok: u T01 upitu postoje dve tabele koje imaju kolonu `Quantity`, pa `SUM(Quantity)` nije jednoznačan.

Promena:

```sql
-- PRE
SELECT SUM(Quantity)
-- POSLE
SELECT SUM(r.Quantity)
```

U SSMS-u je dovoljno da otvorite `testing/01_integration_tests.sql`, izmenite T01 proveru i izvršite samo T01 blok (od `-- T01` do prvog `GO` pre `-- T02`). Prethodni T02-T08 su vec potvrdjeni, ne treba ponavljati T07 test koji skenira stotine hiljada redova.

Rezultat za T01 jos treba potvrditi na lokalnom SQL Server-u; `PASS T01` je ocekivani izlaz, a eventualnu gresku treba sacuvati za dodatnu korekciju.
