<#
.SYNOPSIS
    Unpacks or packs a Power Platform solution for source control.

.DESCRIPTION
    Uses PAC CLI to unpack a solution .zip into individual files (for source
    control diffing/versioning) or pack files back into a .zip for deployment.

.PARAMETER Action
    Either 'Unpack' (zip → folder) or 'Pack' (folder → zip).

.PARAMETER ZipPath
    Path to the solution .zip file (input for Unpack, output for Pack).

.PARAMETER OutputFolder
    Folder for unpacked solution files. Default: .\solution\unpacked

.PARAMETER SolutionType
    Type of solution: 'Both', 'Managed', or 'Unmanaged'. Default: Both

.EXAMPLE
    .\04-unpack-pack.ps1 -Action Unpack -ZipPath ".\solution\PlannerAdoIntegration.zip"
    .\04-unpack-pack.ps1 -Action Pack -ZipPath ".\solution\PlannerAdoIntegration_repacked.zip" -OutputFolder ".\solution\unpacked"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Unpack", "Pack")]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [string]$OutputFolder = ".\solution\unpacked",

    [ValidateSet("Both", "Managed", "Unmanaged")]
    [string]$SolutionType = "Both"
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Solution $Action" -ForegroundColor Cyan
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

if ($Action -eq "Unpack") {
    # --- Unpack: .zip → folder ---

    if (-not (Test-Path $ZipPath)) {
        Write-Error "Solution zip not found: $ZipPath"
        exit 1
    }

    # Create output folder
    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    Write-Host "Unpacking solution..." -ForegroundColor Yellow
    Write-Host "  Source:  $ZipPath" -ForegroundColor Gray
    Write-Host "  Target:  $OutputFolder" -ForegroundColor Gray
    Write-Host "  Type:    $SolutionType" -ForegroundColor Gray
    Write-Host ""

    $unpackArgs = @(
        "solution", "unpack"
        "--zipFile", $ZipPath
        "--folder", $OutputFolder
        "--packagetype", $SolutionType
        "--allowDelete", "Yes"
        "--allowWrite", "Yes"
    )

    pac @unpackArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unpack failed. Check the error output above."
        exit 1
    }

    Write-Host ""
    Write-Host "Unpack successful." -ForegroundColor Green
    Write-Host ""
    Write-Host "Unpacked contents:" -ForegroundColor Yellow
    Get-ChildItem -Path $OutputFolder -Recurse -Directory | ForEach-Object {
        Write-Host "  $($_.FullName.Replace((Resolve-Path $OutputFolder).Path, '.'))" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  - Review the unpacked files" -ForegroundColor Gray
    Write-Host "  - Commit to source control (git add, git commit)" -ForegroundColor Gray
    Write-Host "  - To repack: .\04-unpack-pack.ps1 -Action Pack -ZipPath `".\solution\repacked.zip`" -OutputFolder `"$OutputFolder`"" -ForegroundColor Gray
}
else {
    # --- Pack: folder → .zip ---

    if (-not (Test-Path $OutputFolder)) {
        Write-Error "Unpacked folder not found: $OutputFolder"
        exit 1
    }

    Write-Host "Packing solution..." -ForegroundColor Yellow
    Write-Host "  Source:  $OutputFolder" -ForegroundColor Gray
    Write-Host "  Target:  $ZipPath" -ForegroundColor Gray
    Write-Host "  Type:    $SolutionType" -ForegroundColor Gray
    Write-Host ""

    # Ensure target directory exists
    $zipDir = Split-Path -Path $ZipPath -Parent
    if ($zipDir -and -not (Test-Path $zipDir)) {
        New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    }

    $packArgs = @(
        "solution", "pack"
        "--zipFile", $ZipPath
        "--folder", $OutputFolder
        "--packagetype", $SolutionType
    )

    pac @packArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Pack failed. Check the error output above."
        exit 1
    }

    Write-Host ""
    Write-Host "Pack successful." -ForegroundColor Green
    Write-Host "  File: $ZipPath" -ForegroundColor Green
    Write-Host "  Size: $((Get-Item $ZipPath).Length / 1KB -as [int]) KB" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  - Import to target: .\03-import-solution.ps1 -SolutionZipPath `"$ZipPath`"" -ForegroundColor Gray
}

Write-Host ""
