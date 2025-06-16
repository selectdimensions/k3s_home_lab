# 🧪 Example Usage
# .\Show-ProjectStructure.ps1 -RootPath "C:\Users\Jenkins\Documents\k3s_home_lab"

# 🧪 Optional: Specify custom output filename:
# .\Show-ProjectStructure.ps1 -RootPath "C:\path\to\project" -OutputFile "C:\path\to\project\structure.txt"

param (
    [string]$RootPath = "$PWD",
    [string[]]$ExcludeDirs = @('.git', 'node_modules', '.terraform'),
    [string]$OutputFile = ""
)

function Show-ProjectStructure {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if (-not $OutputFile) {
        $OutputFile = Join-Path $RootPath "project-structure-$timestamp.txt"
    }

    # Create or clear the file
    "" | Set-Content -Path $OutputFile

    $header = @"
📊 Project Structure Analysis:
========================================
"@
    Write-Host "`n$header" -ForegroundColor Cyan
    Add-Content -Path $OutputFile -Value $header

    $items = Get-ChildItem -Path $RootPath -Recurse -Force | Where-Object {
        $_.PSIsContainer -and ($ExcludeDirs -notcontains $_.Name)
    }

    $sorted = $items | Sort-Object FullName

    foreach ($item in $sorted) {
        $relativeDepth = ($item.FullName -split '[\\\/]').Count - ($RootPath -split '[\\\/]').Count
        $indent = '  ' * $relativeDepth
        $line = "$indent📁 $($item.Name)"
        Write-Host $line -ForegroundColor Yellow
        Add-Content -Path $OutputFile -Value $line
    }

    Write-Host "`n📄 Files in Root:" -ForegroundColor Magenta
    Add-Content -Path $OutputFile -Value "`n📄 Files in Root:"

    Get-ChildItem -Path $RootPath -File | ForEach-Object {
        $fileLine = "  📄 $($_.Name)"
        Write-Host $fileLine -ForegroundColor Gray
        Add-Content -Path $OutputFile -Value $fileLine
    }

    Write-Host "`n📁 Project structure saved to: $OutputFile" -ForegroundColor Green
}

Show-ProjectStructure
