<#
.SYNOPSIS
    Packages and deploys the workflow definitions into the Logic App (Standard).

.DESCRIPTION
    Builds a zip of ../workflows (host.json, connections.json, and each workflow's
    workflow.json) and zip-deploys it to the target Logic App. Prints the
    HTTP trigger URL for Flow B, which is needed to register the ADO service hook.

.PARAMETER ResourceGroupName
    Resource group containing the Logic App.

.PARAMETER LogicAppName
    Name of the Logic App Standard site (emitted by 01-deploy-infra.ps1).

.EXAMPLE
    .\03-deploy-workflows.ps1 -ResourceGroupName rg-plannerado -LogicAppName la-plannerado-abc123
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$LogicAppName
)

$ErrorActionPreference = 'Stop'

$workflowsRoot = Join-Path $PSScriptRoot '..\workflows'
$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "workflows-$(Get-Date -Format 'yyyyMMddHHmmss').zip"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Deploy Workflows to $LogicAppName" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Packaging workflows from $workflowsRoot ..." -ForegroundColor Yellow
if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
Compress-Archive -Path (Join-Path $workflowsRoot '*') -DestinationPath $tempZip -Force
Write-Host "  Package: $tempZip" -ForegroundColor Green

Write-Host "[2/4] Verifying Logic App exists..." -ForegroundColor Yellow
$site = az resource show `
    --resource-group $ResourceGroupName `
    --name $LogicAppName `
    --resource-type 'Microsoft.Web/sites' 2>$null | ConvertFrom-Json
if (-not $site) {
    Write-Error "Logic App '$LogicAppName' not found in '$ResourceGroupName'."
    exit 1
}
Write-Host "  Found: $($site.id)" -ForegroundColor Green

Write-Host "[3/4] Zip-deploying workflows..." -ForegroundColor Yellow
az functionapp deployment source config-zip `
    --resource-group $ResourceGroupName `
    --name $LogicAppName `
    --src $tempZip `
    --output none
if ($LASTEXITCODE -ne 0) {
    Write-Error "Zip deployment failed."
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "  Deployed." -ForegroundColor Green
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

Write-Host "[4/4] Retrieving Flow B HTTP trigger URL..." -ForegroundColor Yellow
Write-Host "  Waiting 15s for runtime to register the workflow..." -ForegroundColor Gray
Start-Sleep -Seconds 15

$callbackUrl = $null
$attempts = 0
while ($attempts -lt 6 -and -not $callbackUrl) {
    $attempts++
    try {
        $resp = az rest --method POST `
            --uri "https://management.azure.com$($site.id)/hostruntime/runtime/webhooks/workflow/api/management/workflows/flow-b-ado-to-planner/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2022-09-01" `
            2>$null | ConvertFrom-Json
        if ($resp.value) { $callbackUrl = $resp.value }
    }
    catch {}
    if (-not $callbackUrl) { Start-Sleep -Seconds 10 }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Workflows Deployed" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($callbackUrl) {
    Write-Host "Flow B trigger URL (save this for the ADO service hook):" -ForegroundColor Yellow
    Write-Host $callbackUrl -ForegroundColor White
    Write-Host ""
    Write-Host "Next: .\04-configure-ado-service-hook.ps1 -AdoOrg <org> -AdoProject <project> -CallbackUrl '$callbackUrl'" -ForegroundColor Cyan
}
else {
    Write-Warning "Could not auto-retrieve Flow B trigger URL. Find it manually in the portal:"
    Write-Warning "  Logic App $LogicAppName → Workflows → flow-b-ado-to-planner → Overview → 'Workflow URL'."
}
