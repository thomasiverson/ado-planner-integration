<#
.SYNOPSIS
    Registers an Azure DevOps service hook that POSTs to Flow B when work items are updated.

.DESCRIPTION
    Creates a subscription against the 'workitem.updated' event in the target ADO project,
    filtered to your work item type, with the Logic App's HTTP trigger URL as the webhook target.

    Filtering by state is intentionally NOT applied at the service-hook layer (ADO does not allow
    filtering on "transitioned to X" reliably). Instead, the workflow itself checks the new state
    and terminates early for non-closed transitions.

.PARAMETER AdoOrg
    The Azure DevOps organization name.

.PARAMETER AdoProject
    The target project name.

.PARAMETER CallbackUrl
    Flow B's HTTP trigger URL (emitted by 03-deploy-workflows.ps1).

.PARAMETER WorkItemType
    Work item type to filter on. Default: Task.

.EXAMPLE
    .\04-configure-ado-service-hook.ps1 -AdoOrg contoso -AdoProject ProductBacklog -CallbackUrl 'https://...'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AdoOrg,

    [Parameter(Mandatory = $true)]
    [string]$AdoProject,

    [Parameter(Mandatory = $true)]
    [string]$CallbackUrl,

    [string]$WorkItemType = 'Task'
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Register ADO Service Hook for Flow B" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Acquire ADO bearer token via az cli ---
Write-Host "[1/3] Acquiring ADO access token..." -ForegroundColor Yellow
$token = az account get-access-token --resource '499b84ac-1321-427f-aa17-267ca6975798' --query accessToken -o tsv
if (-not $token) {
    Write-Error "Failed to acquire token. Run 'az login' first."
    exit 1
}
Write-Host "  Token acquired." -ForegroundColor Green

# --- Lookup project ID ---
Write-Host "[2/3] Looking up project '$AdoProject' in org '$AdoOrg'..." -ForegroundColor Yellow
$headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
$projUri = "https://dev.azure.com/$AdoOrg/_apis/projects/$([Uri]::EscapeDataString($AdoProject))?api-version=7.1"
$project = Invoke-RestMethod -Method Get -Uri $projUri -Headers $headers
if (-not $project.id) {
    Write-Error "Project '$AdoProject' not found or you lack permission."
    exit 1
}
Write-Host "  Project ID: $($project.id)" -ForegroundColor Green

# --- Create subscription ---
Write-Host "[3/3] Creating service hook subscription..." -ForegroundColor Yellow
$body = @{
    publisherId = 'tfs'
    eventType = 'workitem.updated'
    resourceVersion = '1.0'
    consumerId = 'webHooks'
    consumerActionId = 'httpRequest'
    publisherInputs = @{
        projectId = $project.id
        workItemType = $WorkItemType
        changedFields = 'System.State'
    }
    consumerInputs = @{
        url = $CallbackUrl
    }
} | ConvertTo-Json -Depth 5

$subUri = "https://dev.azure.com/$AdoOrg/_apis/hooks/subscriptions?api-version=7.1"
$sub = Invoke-RestMethod -Method Post -Uri $subUri -Headers $headers -Body $body

Write-Host "  Subscription ID: $($sub.id)" -ForegroundColor Green
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Service Hook Registered" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verify at: https://dev.azure.com/$AdoOrg/$AdoProject/_settings/serviceHooks" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: validate end-to-end with docs/TESTING.md" -ForegroundColor Cyan
