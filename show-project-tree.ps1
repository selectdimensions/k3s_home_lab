# ✅ Usage
# Run it from your project root (or supply a path):
# cd C:\Users\Jenkins\Documents\k3s_home_lab
# .\scripts\project-tree.ps1 -RootPath "." -OutputFile "project-structure.txt"

# Or from anywhere:
# .\scripts\project-tree.ps1 -RootPath "C:\Users\Jenkins\Documents\k3s_home_lab"

# 📄 Example Output (Partial)
# Folder PATH listing
# Volume serial number is 0C96-A3D2
# C:\Users\Jenkins\Documents\k3s_home_lab

# +---.github
# |   dependabot.yml
# |   +---workflows
# |   |   backup-dr.yml
# |   |   ci-cd-main.yml
# |   |   ...
# +---docs
# |   DEVELOPMENT-SETUP.md
# |   ...
# +---terraform
# |   backend.tf
# |   +---environments
# |   |   +---dev
# |   |   |   main.tf
# |   |   ...

param (
    [string]$RootPath = ".",
    [string]$OutputFile = "project-structure.txt"
)

function Write-Tree {
    param (
        [string]$Path,
        [int]$Indent = 0,
        [System.IO.StreamWriter]$Writer
    )

    $indentStr = "|" + ("   " * $Indent)

    # Print folders first
    Get-ChildItem -Path $Path -Directory | Where-Object {
        $_.Name -notin @(".git", "node_modules", ".terraform")
    } | Sort-Object Name | ForEach-Object {
        $Writer.WriteLine("$indentStr+---$($_.Name)")
        Write-Tree -Path $_.FullName -Indent ($Indent + 1) -Writer $Writer
    }

    # Then print files
    Get-ChildItem -Path $Path -File | Sort-Object Name | ForEach-Object {
        $Writer.WriteLine("$indentStr|   $($_.Name)")
    }
}

# Resolve full path
$ResolvedPath = Resolve-Path $RootPath
$OutputPath = Join-Path $ResolvedPath $OutputFile

# Create writer
$writer = New-Object System.IO.StreamWriter($OutputPath, $false)
$volume = (Get-PSDrive -Name ($ResolvedPath.Drive.Name)).VolumeSerialNumber

$writer.WriteLine("Folder PATH listing")
$writer.WriteLine("Volume serial number is $volume")
$writer.WriteLine("$($ResolvedPath.Path)")
$writer.WriteLine()

Write-Tree -Path $ResolvedPath.Path -Writer $writer

$writer.Close()

Write-Host "✅ Project tree written to $OutputPath"
