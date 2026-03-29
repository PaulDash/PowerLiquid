#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ModuleManifestPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'PowerLiquid.psd1'),

    [string]$MarkdownOutputPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'docs'),

    [string]$ExternalHelpOutputPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'en-US'),

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module PlatyPS -MinimumVersion 0.14.2 -ErrorAction Stop

$resolvedManifestPath = [System.IO.Path]::GetFullPath($ModuleManifestPath)
$resolvedMarkdownOutputPath = [System.IO.Path]::GetFullPath($MarkdownOutputPath)
$resolvedExternalHelpOutputPath = [System.IO.Path]::GetFullPath($ExternalHelpOutputPath)

if (-not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)) {
    throw "Could not find the module manifest at '$resolvedManifestPath'."
}

if ($Force -and (Test-Path -LiteralPath $resolvedMarkdownOutputPath -PathType Container)) {
    Get-ChildItem -LiteralPath $resolvedMarkdownOutputPath -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

foreach ($path in @($resolvedMarkdownOutputPath, $resolvedExternalHelpOutputPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Write-Verbose "Importing module from '$resolvedManifestPath'."
Import-Module $resolvedManifestPath -Force -ErrorAction Stop

$moduleName = (Test-ModuleManifest -Path $resolvedManifestPath).Name

Write-Verbose "Generating markdown help from comment-based help into '$resolvedMarkdownOutputPath'."
New-MarkdownHelp -Module $moduleName -OutputFolder $resolvedMarkdownOutputPath -WithModulePage -Force | Out-Null

Write-Verbose "Generating external help into '$resolvedExternalHelpOutputPath'."
New-ExternalHelp -Path $resolvedMarkdownOutputPath -OutputPath $resolvedExternalHelpOutputPath -Force -Verbose
