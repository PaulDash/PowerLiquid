Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSCommandPath

# Load private implementation files first so exported entry points can rely on the full parser engine.
Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Private') -Filter '*.ps1' -File |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

# Load public command files last.
Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function Invoke-LiquidTemplate, New-LiquidExtensionRegistry, Register-LiquidTag, Register-LiquidFilter
