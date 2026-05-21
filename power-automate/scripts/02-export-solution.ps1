<#
.SYNOPSIS
    Exports the PlannerAdoIntegration solution from a Power Platform environment.

.DESCRIPTION
    Uses PAC CLI to export the solution as a .zip file. Supports both managed
    and unmanaged exports. Ensures you are authenticated and targeting the
    correct environment before export.

.PARAMETER SolutionName
    The unique name of the solution to export. Default: PlannerAdoIntegration

.PARAMETER OutputPath
    Directory where the exported .zip will be saved. Default: .\solution

.PARAMETER Managed
    If specified, exports as a managed solution (recommended for production).
    Otherwise exports as unmanaged.

.PARAMETER EnvironmentUrl
    The Power Platform environment URL. If not specified, uses the currently
    selected environment from pac auth.

.EXAMPLE
    .\02-export-solution.ps1
    .\02-export-solution.ps1 -Managed
    .\02-export-solution.ps1 -SolutionName "PlannerAdoIntegration" -OutputPath ".\solution" -Managed
    .\02-export-solution.ps1 -EnvironmentUrl "https://org12345.crm.dynamics.com" -Managed
#>

[CmdletBinding()]
param(
    [string]$SolutionName = "PlannerAdoIntegration",
    [string]$OutputPath = ".\solution",
    [switch]$Managed,
    [string]$EnvironmentUrl
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Export Solution: $SolutionName" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Verify PAC CLI ---
try {
    $null = pac --version 2>&1
}
catch {
    Write-Error "PAC CLI not found. Run .\01-install-tools.ps1 first."
    exit 1
}

# --- Check auth ---
Write-Host "[1/4] Verifying authentication..." -ForegroundColor Yellow
$authList = pac auth list 2>&1
if ($LASTEXITCODE -ne 0 -or $authList -match "No profiles") {
    Write-Error "Not authenticated to Power Platform. Run: pac auth create"
    exit 1
}
Write-Host "  Authenticated." -ForegroundColor Green

# --- Select environment if specified ---
if ($EnvironmentUrl) {
    Write-Host "[2/4] Selecting environment: $EnvironmentUrl" -ForegroundColor Yellow
    pac env select --environment $EnvironmentUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to select environment: $EnvironmentUrl"
        exit 1
    }
}
else {
    Write-Host "[2/4] Using currently selected environment." -ForegroundColor Yellow
}

# --- Create output directory ---
Write-Host "[3/4] Preparing output directory..." -ForegroundColor Yellow
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "  Created: $OutputPath" -ForegroundColor Green
}
else {
    Write-Host "  Exists: $OutputPath" -ForegroundColor Green
}

# --- Build export file name ---
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$suffix = if ($Managed) { "_managed" } else { "" }
$zipFileName = "${SolutionName}${suffix}_${timestamp}.zip"
$zipFilePath = Join-Path $OutputPath $zipFileName

# --- Export ---
Write-Host "[4/4] Exporting solution..." -ForegroundColor Yellow
Write-Host "  Solution:  $SolutionName" -ForegroundColor Gray
Write-Host "  Type:      $(if ($Managed) { 'Managed' } else { 'Unmanaged' })" -ForegroundColor Gray
Write-Host "  Output:    $zipFilePath" -ForegroundColor Gray
Write-Host ""

$exportArgs = @(
    "solution", "export"
    "--name", $SolutionName
    "--path", $zipFilePath
)

if ($Managed) {
    $exportArgs += "--managed"
}

pac @exportArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Solution export failed. Check the solution name and your permissions."
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Export Successful" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  File: $zipFilePath" -ForegroundColor Green
Write-Host "  Size: $((Get-Item $zipFilePath).Length / 1KB -as [int]) KB" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  Import to target:  .\03-import-solution.ps1 -SolutionZipPath `"$zipFilePath`"" -ForegroundColor Gray
Write-Host "  Unpack for SCM:    .\04-unpack-pack.ps1 -Action Unpack -ZipPath `"$zipFilePath`"" -ForegroundColor Gray
Write-Host ""
