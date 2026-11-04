# RetailOps v1.5 — integracioni testovi

Testovi u `testing/01_integration_tests.sql` revidirani su tako da T05, T06 i T07 koriste grupne upite, umesto ponovljenih korelisanih skeniranja velikih tabela.

## Kako pokrenuti
1. SQL Server Management Studio → `\.\SQLEXPRESS` → baza `RetailOpsDB`.
2. Otvori `testing/01_integration_tests.sql` iz **v1.5** paketa.
3. Execute (F5). Proveri *Messages*: treba da se pojavi `PASS T01` do `PASS T08`.
4. Ukoliko postoji `Msg ...` ili `FAIL`, pošalji screenshot *Messages* i nemoj nastavljati dalje.

T01–T04 i T08 upisuju promene unutar transakcija koje se na kraju vraćaju (`ROLLBACK`), dok su T05–T07 samo za čitanje. Ne pokretati na produkcionom serveru ili tamo gde drugi korisnici rade istovremeno.

Ove izmene su statički pregledane, ali izvršavanje mora da se potvrdi na lokalnom SQL Server-u.
