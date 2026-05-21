<#
.SYNOPSIS
    Imports the PlannerAdoIntegration solution into a Power Platform environment.

.DESCRIPTION
    Uses PAC CLI to import a solution .zip file into the target Power Platform
    environment. Supports publishing customizations after import and activating
    flows.

.PARAMETER SolutionZipPath
    Path to the solution .zip file to import.

.PARAMETER TargetEnvironment
    The target Power Platform environment URL. If not specified, uses the
    currently selected environment.

.PARAMETER PublishAfterImport
    If specified, publishes all customizations after import. Default: true.

.PARAMETER ActivateFlows
    If specified, activates (turns on) all flows in the solution after import.

.EXAMPLE
    .\03-import-solution.ps1 -SolutionZipPath ".\solution\PlannerAdoIntegration_managed.zip"
    .\03-import-solution.ps1 -SolutionZipPath ".\solution\PlannerAdoIntegration_managed.zip" -TargetEnvironment "https://org99999.crm.dynamics.com"
    .\03-import-solution.ps1 -SolutionZipPath ".\solution\PlannerAdoIntegration_managed.zip" -ActivateFlows
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SolutionZipPath,

    [string]$TargetEnvironment,

    [switch]$PublishAfterImport = $true,

    [switch]$ActivateFlows
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Import Solution" -ForegroundColor Cyan
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

# --- Verify solution file exists ---
if (-not (Test-Path $SolutionZipPath)) {
    Write-Error "Solution file not found: $SolutionZipPath"
    exit 1
}

$zipFileInfo = Get-Item $SolutionZipPath
Write-Host "  Solution file: $($zipFileInfo.FullName)" -ForegroundColor Gray
Write-Host "  File size:     $($zipFileInfo.Length / 1KB -as [int]) KB" -ForegroundColor Gray
Write-Host ""

# --- Check auth ---
Write-Host "[1/4] Verifying authentication..." -ForegroundColor Yellow
$authList = pac auth list 2>&1
if ($LASTEXITCODE -ne 0 -or $authList -match "No profiles") {
    Write-Error "Not authenticated to Power Platform. Run: pac auth create"
    exit 1
}
Write-Host "  Authenticated." -ForegroundColor Green

# --- Select target environment if specified ---
if ($TargetEnvironment) {
    Write-Host "[2/4] Selecting target environment: $TargetEnvironment" -ForegroundColor Yellow
    pac env select --environment $TargetEnvironment
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to select environment: $TargetEnvironment"
        exit 1
    }
    Write-Host "  Environment selected." -ForegroundColor Green
}
else {
    Write-Host "[2/4] Using currently selected environment." -ForegroundColor Yellow
}

# --- Import ---
Write-Host "[3/4] Importing solution..." -ForegroundColor Yellow
Write-Host "  This may take several minutes for large solutions." -ForegroundColor DarkGray
Write-Host ""

$importArgs = @(
    "solution", "import"
    "--path", $SolutionZipPath
)

if ($PublishAfterImport) {
    $importArgs += "--publish-changes"
}

if ($ActivateFlows) {
    $importArgs += "--activate-plugins"
}

pac @importArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Solution import failed. Check the error output above."
    Write-Host ""
    Write-Host "Common causes:" -ForegroundColor Yellow
    Write-Host "  - Missing dependencies in the target environment" -ForegroundColor Gray
    Write-Host "  - Insufficient permissions (need System Administrator or Customizer role)" -ForegroundColor Gray
    Write-Host "  - Solution already exists with a higher version" -ForegroundColor Gray
    exit 1
}

# --- Post-import steps ---
Write-Host "[4/4] Post-import steps..." -ForegroundColor Yellow

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Import Successful" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT — Complete these manual steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Set Connection References:" -ForegroundColor White
Write-Host "     - Go to make.powerapps.com → Solutions → PlannerAdoIntegration" -ForegroundColor Gray
Write-Host "     - Open Connection References" -ForegroundColor Gray
Write-Host "     - Link Planner and Azure DevOps connections" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Set Environment Variables:" -ForegroundColor White
Write-Host "     - ADO_ORG           = your Azure DevOps org name" -ForegroundColor Gray
Write-Host "     - ADO_PROJECT       = your ADO project name" -ForegroundColor Gray
Write-Host "     - ADO_WORK_ITEM_TYPE = Task (or User Story)" -ForegroundColor Gray
Write-Host "     - PLANNER_GROUP_ID  = M365 Group ID" -ForegroundColor Gray
Write-Host "     - PLANNER_PLAN_ID   = Planner Plan ID" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Turn On Flows:" -ForegroundColor White
Write-Host "     - Open each flow in the solution" -ForegroundColor Gray
Write-Host "     - Click 'Turn on'" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Validate:" -ForegroundColor White
Write-Host "     - Follow the Testing Plan (docs/TESTING_PLAN.md)" -ForegroundColor Gray
Write-Host ""
