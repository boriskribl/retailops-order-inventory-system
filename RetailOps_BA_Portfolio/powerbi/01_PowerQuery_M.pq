// Power BI Desktop > Get Data > Blank Query > Advanced Editor.
// Create FOUR reporting queries plus ONE optional country lookup using the individual expressions below.
// The names must be Sales, Inventory, Fulfillment, Procurement.
// Replace .\SQLEXPRESS with the exact instance shown in SSMS if necessary.

// QUERY: Sales
let
    Source = Sql.Database(".\SQLEXPRESS", "RetailOpsDB"),
    Sales = Source{[Schema="dbo", Item="vw_SalesFact"]}[Data]
in
    Sales

// QUERY: Inventory
let
    Source = Sql.Database(".\SQLEXPRESS", "RetailOpsDB"),
    Inventory = Source{[Schema="dbo", Item="vw_InventoryHealth"]}[Data]
in
    Inventory

// QUERY: Fulfillment
let
    Source = Sql.Database(".\SQLEXPRESS", "RetailOpsDB"),
    Fulfillment = Source{[Schema="dbo", Item="vw_FulfillmentPerformance"]}[Data]
in
    Fulfillment

// QUERY: Procurement
let
    Source = Sql.Database(".\SQLEXPRESS", "RetailOpsDB"),
    Procurement = Source{[Schema="dbo", Item="vw_ProcurementPerformance"]}[Data]
in
    Procurement

// QUERY: DimCountry (optional shared lookup)
let
    Source = Sql.Database(".\SQLEXPRESS", "RetailOpsDB"),
    Countries = Source{[Schema="dbo", Item="Countries"]}[Data]
in
    Countries
