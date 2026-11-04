# RetailOps v1.1 (optional). Run on YOUR Windows computer after extracting the ZIP.
# Requirements: Microsoft SQL Server instance + separately installed sqlcmd utility.
# If sqlcmd is unavailable, follow WINDOWS_SETUP_GITHUB_SR.md and run scripts from SSMS.
param(
    [string]$Server = '.\SQLEXPRESS',
    [switch]$RunTests
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cmd = Get-Command 'sqlcmd' -ErrorAction SilentlyContinue
if (-not $cmd) {
    throw 'sqlcmd not found in PATH. Use SSMS to run the SQL files manually or install sqlcmd from Microsoft.'
}
$files = @(
    'database/00_create_database.sql',
    'database/01_schema.sql',
    'database/02_procedures.sql',
    'database/03_seed_data.sql',
    'database/04_indexes.sql',
    'database/05_views.sql',
    'database/06_demo_workflows.sql',
    'testing/04_post_install_validation.sql'
)
if ($RunTests) {
    $files += @('testing/01_integration_tests.sql', 'testing/02_negative_tests.sql')
}
$log = Join-Path $root 'retailops_local_execution.log'
"RetailOps execution log | Server=$Server | $(Get-Date -Format s)" | Out-File $log -Encoding UTF8
foreach ($file in $files) {
    $path = Join-Path $root ($file -replace '/', '\')
    if (-not (Test-Path $path)) { throw "Missing script: $path" }
    Write-Host "Running: $file" -ForegroundColor Cyan
    # -E Windows Authentication; -C trust the self-signed local SQL Server cert;
    # -b stop on SQL errors; no DROP DATABASE or data removal.
    & $cmd.Source -S $Server -E -C -b -i $path 2>&1 | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) {
        throw "SQL execution failed on $file. STOP; do not restart from script 00. See $log"
    }
}
Write-Host "Setup and verification complete. Log: $log" -ForegroundColor Green
