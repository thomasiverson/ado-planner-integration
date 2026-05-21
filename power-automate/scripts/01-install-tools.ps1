<#
.SYNOPSIS
    Installs prerequisites for Planner-ADO Integration solution management.

.DESCRIPTION
    Installs the Power Platform CLI (PAC CLI) via dotnet tool and verifies
    required tools are available. Optionally authenticates to a Power Platform
    environment.

.PARAMETER Authenticate
    If specified, prompts for interactive authentication to Power Platform after installation.

.EXAMPLE
    .\01-install-tools.ps1
    .\01-install-tools.ps1 -Authenticate
#>

[CmdletBinding()]
param(
    [switch]$Authenticate
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Planner-ADO Integration — Tool Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Check .NET SDK ---
Write-Host "[1/3] Checking .NET SDK..." -ForegroundColor Yellow
try {
    $dotnetVersion = dotnet --version
    Write-Host "  .NET SDK found: $dotnetVersion" -ForegroundColor Green
}
catch {
    Write-Error ".NET SDK is not installed. Install from https://dotnet.microsoft.com/download"
    exit 1
}

# --- Install/Update PAC CLI ---
Write-Host "[2/3] Installing/updating Power Platform CLI (pac)..." -ForegroundColor Yellow

$pacInstalled = dotnet tool list -g | Select-String "Microsoft.PowerApps.CLI.Tool"
if ($pacInstalled) {
    Write-Host "  PAC CLI already installed. Updating..." -ForegroundColor Yellow
    dotnet tool update --global Microsoft.PowerApps.CLI.Tool
}
else {
    Write-Host "  Installing PAC CLI..." -ForegroundColor Yellow
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool
}

# Verify pac is available
try {
    $pacVersion = pac --version 2>&1
    Write-Host "  PAC CLI version: $pacVersion" -ForegroundColor Green
}
catch {
    Write-Warning "PAC CLI installed but not found in PATH. You may need to restart your terminal."
    Write-Warning "Expected location: $env:USERPROFILE\.dotnet\tools"
}

# --- Verify Azure DevOps CLI (optional, for WIQL testing) ---
Write-Host "[3/3] Checking Azure CLI + DevOps extension (optional)..." -ForegroundColor Yellow
try {
    $azVersion = az version 2>&1 | ConvertFrom-Json
    Write-Host "  Azure CLI found: $($azVersion.'azure-cli')" -ForegroundColor Green

    $devopsExt = az extension show --name azure-devops 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Azure DevOps extension: installed" -ForegroundColor Green
    }
    else {
        Write-Host "  Azure DevOps extension not found. Installing..." -ForegroundColor Yellow
        az extension add --name azure-devops
        Write-Host "  Azure DevOps extension: installed" -ForegroundColor Green
    }
}
catch {
    Write-Host "  Azure CLI not found (optional — only needed for WIQL testing)" -ForegroundColor DarkGray
}

# --- Authenticate (optional) ---
if ($Authenticate) {
    Write-Host ""
    Write-Host "Authenticating to Power Platform..." -ForegroundColor Yellow
    Write-Host "A browser window will open for interactive sign-in." -ForegroundColor DarkGray
    pac auth create
    Write-Host ""
    Write-Host "Current auth profiles:" -ForegroundColor Yellow
    pac auth list
}

# --- Summary ---
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Setup Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Authenticate to Power Platform:  pac auth create" -ForegroundColor Gray
Write-Host "  2. List environments:                pac env list" -ForegroundColor Gray
Write-Host "  3. Select environment:               pac env select --environment <env-id>" -ForegroundColor Gray
Write-Host "  4. Export solution:                   .\02-export-solution.ps1" -ForegroundColor Gray
Write-Host ""
