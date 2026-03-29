Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the module root once so private and public files can be loaded relative to the manifest.
$moduleRoot = Split-Path -Parent $PSCommandPath

# Load private implementation files first so parsing, rendering, and helper functions are available.
Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Private') -Filter '*.ps1' -File |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

# Load the public command wrappers after the engine so exported commands can add help and top-level handling.
Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

# Export the supported public surface explicitly.
Export-ModuleMember -Function Invoke-LiquidTemplate, ConvertTo-LiquidAst, New-LiquidExtensionRegistry, Register-LiquidTag, Register-LiquidFilter, Register-LiquidTrustedType