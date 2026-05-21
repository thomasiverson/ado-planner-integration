<#
.SYNOPSIS
    Deploys the Planner-ADO Logic Apps infrastructure to a resource group.

.DESCRIPTION
    Wraps `az deployment group create` to deploy the Bicep template in
    ../infra/main.bicep using ../infra/main.bicepparam. Prints outputs needed
    by subsequent phases.

.PARAMETER ResourceGroupName
    Target resource group. Must already exist.

.PARAMETER BicepParamFile
    Path to a .bicepparam file. Default: ../infra/main.bicepparam (relative to this script).

.EXAMPLE
    .\01-deploy-infra.ps1 -ResourceGroupName rg-plannerado
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [string]$BicepParamFile = (Join-Path $PSScriptRoot '..\infra\main.bicepparam')
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Deploy Planner-ADO Logic Apps Infra" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Verify Azure CLI ---
Write-Host "[1/4] Verifying Azure CLI..." -ForegroundColor Yellow
try {
    $null = az --version 2>&1
}
catch {
    Write-Error "Azure CLI not found. Install: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}
Write-Host "  Azure CLI: OK" -ForegroundColor Green

# --- Verify signed in ---
Write-Host "[2/4] Verifying Azure sign-in..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not signed in. Run: az login"
    exit 1
}
Write-Host "  Subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# --- Verify RG exists ---
Write-Host "[3/4] Verifying resource group '$ResourceGroupName'..." -ForegroundColor Yellow
$rg = az group show --name $ResourceGroupName 2>$null | ConvertFrom-Json
if (-not $rg) {
    Write-Error "Resource group '$ResourceGroupName' not found. Create it with: az group create --name $ResourceGroupName --location <region>"
    exit 1
}
Write-Host "  Location: $($rg.location)" -ForegroundColor Green

# --- Deploy ---
Write-Host "[4/4] Deploying Bicep template..." -ForegroundColor Yellow
Write-Host "  Param file: $BicepParamFile" -ForegroundColor Gray
Write-Host ""

$deploymentName = "plannerado-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroupName `
    --parameters $BicepParamFile `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed. Check 'az deployment group show --name $deploymentName --resource-group $ResourceGroupName' for details."
    exit 1
}

$outputs = az deployment group show --name $deploymentName --resource-group $ResourceGroupName --query properties.outputs | ConvertFrom-Json

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Deployment Successful" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Outputs (save these for the next phases):" -ForegroundColor Yellow
Write-Host "  logicAppName             : $($outputs.logicAppName.value)"
Write-Host "  logicAppHostname         : $($outputs.logicAppHostname.value)"
Write-Host "  managedIdentityName      : $($outputs.managedIdentityName.value)"
Write-Host "  managedIdentityClientId  : $($outputs.managedIdentityClientId.value)"
Write-Host "  managedIdentityPrincipalId : $($outputs.managedIdentityPrincipalId.value)"
Write-Host "  storageAccountName       : $($outputs.storageAccountName.value)"
Write-Host ""
Write-Host "Next: .\02-grant-graph-permissions.ps1 -ManagedIdentityObjectId $($outputs.managedIdentityPrincipalId.value)" -ForegroundColor Cyan
