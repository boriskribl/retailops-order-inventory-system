# RetailOps — instalacija na Windows-u i objavljivanje na GitHub-u

## A. Lokalni fajlovi (5 minuta rada bez SQL-a)

1. Preuzmi ZIP sa ovim projektom i u Windows Explorer-u desni klik → **Extract All**.
2. Predlog lokacije: `C:\Users\<tvoje-korisnicko-ime>\Documents\RetailOps_BA_Portfolio` (mora se videti `README.md` direktno u folderu).
3. **Ne kopiraj ZIP u SQL Server**. ZIP sadrži izvorni kod; SQL Server baza se gradi pokretanjem `.sql` skripti.
4. Sačuvaj ZIP kao rezervnu kopiju. Svaku grešku analiziramo pre nastavka; nikad nemoj ponovo pokretati instalaciju od početka u već popunjenoj bazi.

## B. SQL Server Management Studio (SSMS) — preporučeno

Povezivanje koje je već radilo: server ` .\\SQLEXPRESS ` (**bez razmaka**, tj. `.\SQLEXPRESS`), **Windows Authentication**, *Trust Server Certificate* za lokalni razvoj.

1. SSMS → **File → Open → File** → otvori `database/00_create_database.sql`.
2. Klikni **Execute** / F5. Očekuj rezultate koji pokazuju `RetailOpsDB`.
3. Otvori `database/01_schema.sql` i F5. Sačekaj `RetailOps schema created: 25 tables`.
4. Otvori redom `02_procedures.sql`, `03_seed_data.sql`, `04_indexes.sql`, `05_views.sql`, `06_demo_workflows.sql`; za **svaki pojedinačno** F5. `03_seed_data.sql` može biti sporiji (100.000 sintetičkih porudžbina).
5. Zatim `testing/04_post_install_validation.sql` i F5. U tabu **Messages** očekuj PASS **V01–V07**.
6. Pokreni `testing/01_integration_tests.sql`; očekuj PASS **T01–T08**. Potom `testing/02_negative_tests.sql` za **N01–N03**. Sačuvaj screenshot Messages taba. Nemoj izmišljati rezultate ako bilo šta padne.
7. Pokreni `analytics/01_business_questions.sql` da vidiš konkretne poslovne analize.

> Ako neki korak prijavi grešku, **stani**. Zapiši **koji fajl** si pokrenuo i kopiraj **ceo tekst iz Messages**. Nemoj ponavljati `01_schema.sql` ili `03_seed_data.sql` na istoj bazi. Nema automatskog brisanja postojeće baze.

### Opcionalno automatizovan SQL setup

Ako imaš instaliran `sqlcmd` kao poseban alat, PowerShell pokrenut u korenom folderu može izvršiti:

```powershell
.\tools\run_on_windows.ps1 -Server '.\SQLEXPRESS' -RunTests
```

Skripta prekida rad na grešci i zapisuje lokalni log. Nije obavezna. Ako `sqlcmd` nije instaliran, izaberi ručnu varijantu preko SSMS-a.

## C. Power BI na istom Windows računaru

1. Instaliraj/otvori Power BI Desktop.
2. **Get data → SQL Server**, Server `.\SQLEXPRESS`, Database `RetailOpsDB`, Import, Windows credentials.
3. Uvezi 4 SQL views: `vw_SalesFact`, `vw_InventoryHealth`, `vw_FulfillmentPerformance`, `vw_ProcurementPerformance`. Dodaj `Countries` opciono.
4. Prati `powerbi/04_dashboard_design.md` za veze, DAX mere i tri stranice.
5. Sačuvaj `powerbi/RetailOps_Operations_Dashboard.pbix` i 3 screenshot-a u `assets/screenshots/` (napravi folder). **Proveri da refresh radi**.
6. Poredi `SUM(NetRevenueEUR)` i `COUNT(*)` iz SQL-a sa Power BI prikazom pre nego što navedeš metrike u CV-u.

## D. GitHub — najlakše kroz GitHub Desktop (bez komandne linije)

1. Instaliraj [GitHub Desktop](https://desktop.github.com/) i prijavi se na GitHub nalog.
2. GitHub Desktop → **File → Add local repository** → izaberi folder `RetailOps_BA_Portfolio` koji si raspakovao.
3. Ako ti ponudi **Create a Repository**, potvrdi. Unesi kratak opis projekta, i **nemoj dodavati drugi README** — već postoji.
4. U **Changes** proveri da su SQL skripte, BRD/SRS, ERD, README itd. svi uključeni. Ne dodaj `.bak`, `.mdf`, `.ldf`, lokalne logove ili lične podatke.
5. U polje *Summary* upiši: `Initial RetailOps business analysis portfolio` → klikni **Commit to main**.
6. Klikni **Publish repository**. Preporučujem da prvi put izabereš **Private** dok lokalne testove i dashboard ne završimo, pa posle promeni na Public kad imaš dokaze i screenshot-e.
7. GitHub Desktop posle toga omogućava **Push origin** kada dopunjuješ kod. Sačuvaj link repozitorijuma za CV tek kada je projekat spreman za javno predstavljanje.

Alternativa, ako imaš instaliran Git i više voliš terminal (prethodno ručno napravi **prazan** GitHub repo bez README-a):

```powershell
cd "$HOME\Documents\RetailOps_BA_Portfolio"
git init
git add .
git commit -m "Initial RetailOps business analysis portfolio"
git branch -M main
git remote add origin https://github.com/TVOJ_USERNAME/retailops-business-analysis.git
git push -u origin main
```

Zameni `TVOJ_USERNAME` stvarnim GitHub korisničkim imenom. GitHub može zatražiti prijavu kroz browser. Nigde u komande ne unosi lozinku javno.

## E. Šta mi pošalješ u chatu da nastavimo precizno

Pošalji **screenshot Messages** nakon što pokreneš `00_create_database.sql` i `01_schema.sql`. Zatim idemo kroz sledeće fajlove bez preskakanja grešaka. Kada prođu testovi, radićemo Power BI i GitHub objavu. 

**Napomena:** Ne mogu iz ovog chata direktno pristupiti tvom Windows disku. Povezivanje GitHub naloga kroz ChatGPT, ako izabereš, može pomoći oko objavljivanja koda, ali lokalni SQL Server i Power BI moraju se izvršiti na tvom računaru.
