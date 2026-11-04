# Kako da predstaviš RetailOps na Business Analyst intervjuu

**Na početku jasno reci:** „Ovo je moj samostalni portfolio projekat zasnovan na simuliranom poslovnom slučaju. Koristio sam AI kao podršku pri pripremi tehničkih materijala i zatim sam sam testirao i analizirao projektovano ponašanje.” *Drugi deo govori tek kada si zaista uradio lokalne testove.*

## Pitch od 90 sekundi

> "I created RetailOps, an enterprise order and inventory management case study for a fictional retailer operating in Serbia, Croatia and Slovenia. The initial business problem was the risk of overselling and inconsistent inventory visibility across channels and warehouses. I first documented stakeholders, business objectives, system scope and measurable acceptance criteria. I then translated those into user stories and a target workflow: order entry, available-to-promise check, atomic warehouse reservation, dispatch, delivery and KPI reporting. The SQL prototype represents these rules with relational constraints, transactions and procedures, including a domestic-first warehouse allocation policy. I also prepared requirements traceability, test scenarios and a Power BI reporting model. The biggest design trade-off is a deliberately narrow prototype scope: it does not include payment services, FX, or a live user interface. I would validate these rules with real users before production work." 

## Jedan jak BA scenario (od zahteva do SQL-a)

| Korak | Šta pokazuješ | Gde se nalazi |
|---|---|---|
| Problem | „Two customers may reserve the last unit of stock.” | BRD — BP-01 |
| Zahtev | FR-03 / US-03: no overselling, atomic reservation | SRS, backlog |
| Poslovno pravilo | AvailableQty = OnHand - Reserved; ili cela porudžbina ili ništa | KPI dictionary, procedure |
| Tehničko rešenje | `usp_AllocateOrder` with row locks and rollback | `database/02_procedures.sql` |
| Verifikacija | T01, N01, C01 | `testing/` |
| Poslovna odluka | Najmanje otkazivanja, ali uz kompromis zaključavanja / throughput | Quality review / presentation |

## Tipična pitanja i dobar okvir odgovora

**Zašto prvo BRD, a ne SQL?** Da se model podataka i pravila zasnivaju na korisničkom problemu, a ne na nasumično biranim tabelama.

**Zašto je `QuantityReserved` odvojena od `QuantityOnHand`?** Rezervacija predstavlja poslovnu obavezu, ali fizički stock napušta skladište tek kada se pošiljka dispatch-uje. Sprečava lažno smanjenje fizičkih zaliha pre isporuke.

**Zašto nije dovoljna provera dostupnosti pre UPDATE?** Dve paralelne transakcije bi mogle pročitati isti broj; potrebni su zaključavanje i kontrolisana atomarna promena.

**Koja je mana domestic-first politike?** Može povećati broj odvojenih isporuka ili troškove; sledeća verzija bi rangirala skladišta i po ukupnoj ceni, SLA i emisijama.

**Zašto nisu implementirani API ili frontend?** Ovo je BA/System Analysis dokaz poslovne logike i specifikacije, ne demonstracija full-stack isporuke.

**Da li je poboljšan on-time delivery ili smanjen overselling?** Ne postoje realni poslovni podaci. Pokazujemo očekivano ponašanje sintetičkog prototipa; nikada ne iznosimo neizmereni ROI.

**Kako je korišćen AI?** Kao alat za izradu nacrta SQL-a, dokumentacije i testova; čovek ostaje odgovoran za poslovna pravila, razumevanje, izvršavanje, reviziju i prezentovanje rezultata.
