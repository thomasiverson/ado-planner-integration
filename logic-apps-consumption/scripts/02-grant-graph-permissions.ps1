<#
.SYNOPSIS
    Grants (or revokes) Microsoft Graph application permissions to the Planner-ADO managed identity.

.DESCRIPTION
    Assigns the following Graph app roles to the user-assigned managed identity's service principal:
      - Tasks.ReadWrite.All  (for reading Planner tasks and marking them complete)
      - Group.Read.All       (for resolving the Planner plan's owning M365 group)

    Requires Global Administrator or Privileged Role Administrator at the time of execution.

.PARAMETER ManagedIdentityObjectId
    The Object ID (Principal ID) of the user-assigned managed identity. Emitted by 01-deploy-infra.ps1.

.PARAMETER Revoke
    If specified, removes the assignments instead of adding them.

.EXAMPLE
    .\02-grant-graph-permissions.ps1 -ManagedIdentityObjectId 00000000-1111-2222-3333-444444444444
    .\02-grant-graph-permissions.ps1 -ManagedIdentityObjectId 00000000-1111-2222-3333-444444444444 -Revoke
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManagedIdentityObjectId,

    [switch]$Revoke
)

$ErrorActionPreference = 'Stop'

$rolesToGrant = @('Tasks.ReadWrite.All', 'Group.Read.All')
$graphAppId = '00000003-0000-0000-c000-000000000000'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Graph App Role $(if ($Revoke) { 'Revocation' } else { 'Assignment' })" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Ensuring Microsoft.Graph PowerShell module is available..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable Microsoft.Graph.Applications)) {
    Write-Host "  Installing Microsoft.Graph.Applications (current user scope)..." -ForegroundColor Gray
    Install-Module Microsoft.Graph.Applications -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Applications

Write-Host "[2/3] Connecting to Microsoft Graph (interactive)..." -ForegroundColor Yellow
Connect-MgGraph -Scopes 'AppRoleAssignment.ReadWrite.All', 'Application.Read.All' -UseDeviceCode -NoWelcome

$graphSp = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"
if (-not $graphSp) {
    Write-Error "Microsoft Graph service principal not found in this tenant."
    exit 1
}

Write-Host "[3/3] $(if ($Revoke) { 'Revoking' } else { 'Granting' }) app role assignments..." -ForegroundColor Yellow
foreach ($roleName in $rolesToGrant) {
    $role = $graphSp.AppRoles | Where-Object Value -eq $roleName
    if (-not $role) {
        Write-Warning "  Role '$roleName' not found in Graph service principal — skipping."
        continue
    }

    if ($Revoke) {
        $existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityObjectId |
            Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $graphSp.Id }
        if ($existing) {
            Remove-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityObjectId -AppRoleAssignmentId $existing.Id
            Write-Host "  $roleName : revoked" -ForegroundColor Green
        }
        else {
            Write-Host "  $roleName : not assigned (skip)" -ForegroundColor Gray
        }
    }
    else {
        $existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityObjectId -ErrorAction SilentlyContinue |
            Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $graphSp.Id }
        if ($existing) {
            Write-Host "  $roleName : already assigned (skip)" -ForegroundColor Gray
        }
        else {
            New-MgServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $ManagedIdentityObjectId `
                -PrincipalId $ManagedIdentityObjectId `
                -ResourceId $graphSp.Id `
                -AppRoleId $role.Id | Out-Null
            Write-Host "  $roleName : granted" -ForegroundColor Green
        }
    }
}

Disconnect-MgGraph | Out-Null

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Done" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
if (-not $Revoke) {
    Write-Host "Next: add the managed identity to your Azure DevOps organization." -ForegroundColor Cyan
    Write-Host "      See docs/MANAGED_IDENTITY_SETUP.md, Step 3." -ForegroundColor Cyan
}
