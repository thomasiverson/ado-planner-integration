<#
.SYNOPSIS
    Deploys the Planner-ADO Logic Apps (Consumption) infrastructure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroupName,
    [string]$BicepParamFile = (Join-Path $PSScriptRoot '..\infra\main.bicepparam')
)
$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Deploy Planner-ADO Logic Apps (Consumption)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) { Write-Error "Not signed in. Run: az login"; exit 1 }
Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Green

$rg = az group show --name $ResourceGroupName 2>$null | ConvertFrom-Json
if (-not $rg) { Write-Error "Resource group '$ResourceGroupName' not found."; exit 1 }
Write-Host "Resource group: $ResourceGroupName ($($rg.location))" -ForegroundColor Green

Write-Host "Ensuring required resource providers are registered..." -ForegroundColor Yellow
$rps = @('Microsoft.Logic', 'Microsoft.ManagedIdentity')
foreach ($rp in $rps) {
    $state = az provider show -n $rp --query registrationState -o tsv 2>$null
    if ($state -ne 'Registered') {
        az provider register -n $rp -o none
        do { Start-Sleep 5; $state = az provider show -n $rp --query registrationState -o tsv 2>$null } while ($state -ne 'Registered')
    }
    Write-Host "  $rp : $state" -ForegroundColor Green
}

$deploymentName = "planlc-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Deploying Bicep..." -ForegroundColor Yellow
az deployment group create `
    --name $deploymentName `
    --resource-group $ResourceGroupName `
    --parameters $BicepParamFile `
    --output none
if ($LASTEXITCODE -ne 0) { Write-Error "Deployment failed."; exit 1 }

$o = az deployment group show --name $deploymentName --resource-group $ResourceGroupName --query properties.outputs | ConvertFrom-Json

# Retrieve Flow B callback URL
$flowBName = $o.flowBName.value
$callbackJson = az rest --method POST --uri "https://management.azure.com$($o.flowBResourceId.value)/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2016-06-01" 2>$null | ConvertFrom-Json
$flowBUrl = $callbackJson.value

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Deployment Successful" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "managedIdentityName       : $($o.managedIdentityName.value)"
Write-Host "managedIdentityPrincipalId: $($o.managedIdentityPrincipalId.value)"
Write-Host "managedIdentityResourceId : $($o.managedIdentityResourceId.value)"
Write-Host "flowAName                 : $($o.flowAName.value)"
Write-Host "flowBName                 : $flowBName"
Write-Host "flowBCallbackUrl          : $flowBUrl"
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  .\02-grant-graph-permissions.ps1 -ManagedIdentityObjectId $($o.managedIdentityPrincipalId.value)" -ForegroundColor Cyan
Write-Host "  Then add the MI to ADO org (see ../logic-apps/docs/MANAGED_IDENTITY_SETUP.md Step 3)" -ForegroundColor Cyan
Write-Host "  Then .\03-configure-ado-service-hook.ps1 -AdoOrg <org> -AdoProject <project> -CallbackUrl '$flowBUrl'" -ForegroundColor Cyan
