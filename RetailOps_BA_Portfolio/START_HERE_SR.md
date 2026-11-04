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

## Šta nije završeno bez tvog računara

Nisam se povezao na tvoj SQL Server i nisam mogao da izvršim SQL na tvojoj instalaciji. Testovi su **napisani, ali nisu potvrđeni na tom serveru**. Power BI `.pbix` mora da se napravi u Power BI Desktop-u; u paketu je sve za njegovo povezivanje i izradu, ali nema gotovog aktivnog dashboard-a. GitHub repozitorijum nije automatski objavljen.

## Zašto je ovo dobro za Business Analyst praksu

Na razgovoru nije najvažnije da kažeš „imam 25 tabela i 100.000 redova”, već da pokažeš: koji je poslovni problem, ko je stakeholder, kako si definisao pravilo rezervacije, kako ga SQL implementira, kako test potvrđuje pravilo i kako menadžer vidi rezultat.

**Pre nego što projekat staviš na CV kao završen**, pokreni skripte, sačuvaj realne rezultate testova, sastavi Power BI dashboard, i pripremi objašnjenje ključnih SQL procedura. U prezentaciji jasno reci da je projekat simulacija i da je korišćena AI pomoć pri izradi.
