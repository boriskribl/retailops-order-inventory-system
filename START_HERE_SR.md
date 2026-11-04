# RetailOps — vodič na srpskom

**Ovo je gotov paket projektnih fajlova**, a ne već instalirana baza na tvom računaru.

## Šta je pripremljeno

- Projektna dokumentacija na engleskom: BRD, SRS, user stories, KPI definicije, RACI/RAID i traceability matrica.
- SQL Server šema sa 25 tabela, povezivanjem, ograničenjima, indeksima i sedam stored procedura.
- SQL generator za **100.000 sintetičkih porudžbina**, plus primer kompletne isporuke, povraćaja i prijema robe.
- Integracioni i negativni testovi i uputstvo za paralelni test rezervisanja poslednje jedinice.
- Dvanaest poslovnih SQL analiza i fajl za merenje performansi.
- Pravi BPMN 2.0 XML, ER dijagram i UML sequence (Mermaid).
- Power BI upiti, DAX mere, tema i precizan raspored vizuala za tri stranice.
- GitHub README, Word BRD/SRS dokumenti i PowerPoint prezentacija za intervju.

**Gotovi dokumenti:** `deliverables/RetailOps_Business_Requirements_Document.docx`, `deliverables/RetailOps_System_Requirements_Specification.docx` i `deliverables/RetailOps_Interview_Case_Study.pptx`.

## Kako da pokreneš (kada budeš hteo)

U SSMS-u poveži se na `(.\SQLEXPRESS)` koristeći Windows Authentication. Onda otvori skripte tačno po redu:

```text
1) database/00_create_database.sql
2) database/01_schema.sql
3) database/02_procedures.sql
4) database/03_seed_data.sql
5) database/04_indexes.sql
6) database/05_views.sql
7) database/06_demo_workflows.sql
```

Zatim pokreni `testing/01_integration_tests.sql` i `testing/02_negative_tests.sql`, pa poslovne upite iz `analytics/01_business_questions.sql`.

**Nemoj dva puta da pokrećeš 01_schema.sql ili 03_seed_data.sql.** Baza je predviđena da se prvi put pravi prazna i bez brisanja postojećih podataka.

## Šta je potvrđeno na lokalnom računaru (2026-11-04)

- SQL Server Express: kreirana šema sa 25 tabela, sedam procedura i pet analitičkih pogleda.
- Evidentirani rezultati integracionih testova: **T01–T08 PASS**; negativnih testova **N01–N03 PASS**.
- Konkurentni scenario **C01**: jedna sesija rezervisala dostupnu jedinicu, druga je odbijena očekivanom SQL greškom `51102`.
- Validacije **V01–V06 PASS**; optimizovani V07 proverio `MismatchCount = 0`.
- Power BI `.pbix` se nalazi u `powerbi/` i sadrži tri stranice; screenshotovi su u `assets/`.
- SQL poslovne analize su lokalno izvršene; rezultati su ilustrativni jer je baza sintetička.

Ovo su **lokalno prijavljeni rezultati**, a ne nezavisna reprodukcija, automatski CI test ili verifikacija na produkcionom serveru. Pogledaj `README.md`, `testing/test_execution_log.csv` i `testing/performance_results_template.csv`.

## Šta radiš kada projekat predstavljaš

1. Otvori `README.md` i pokaži povezivanje zahteva, SQL implementacije, testova i Power BI nalaza.
2. Pokaži tri screenshot-a dashboarda i po potrebi lokalni `.pbix`.
3. Objasni osiguranje rezervacije zaliha u `usp_AllocateOrder` i rezultat konkurentnog testa C01.
4. Jasno navedi da su organizacija, stakeholderi i podaci **fiktivni/sintetički**, a da je pri izradi korišćena AI pomoć.
5. Za ponovnu instalaciju koristi **novu praznu demo bazu**. Nemoj ponovno pokretati seed nad postojećom instalacijom.
