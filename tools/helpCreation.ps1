#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ModuleManifestPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'PowerLiquid.psd1'),

    [string]$HelpSourcePath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'docs\help'),

    [switch]$Force
)

break

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Generate PlatyPS markdown help source for the module, its public commands, and the AST API About topic.
Import-Module PlatyPS -MinimumVersion 0.14.2 -ErrorAction Stop

$resolvedManifestPath = [System.IO.Path]::GetFullPath($ModuleManifestPath)
$resolvedHelpSourcePath = [System.IO.Path]::GetFullPath($HelpSourcePath)
$moduleRoot = Split-Path -Parent $resolvedManifestPath

if (-not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)) {
    throw "Could not find the module manifest at '$resolvedManifestPath'."
}

if (-not (Test-Path -LiteralPath $resolvedHelpSourcePath -PathType Container)) {
    New-Item -ItemType Directory -Path $resolvedHelpSourcePath -Force | Out-Null
}

Write-Verbose "Importing module from '$resolvedManifestPath'."
Import-Module $resolvedManifestPath -Force -ErrorAction Stop

$moduleName = (Test-ModuleManifest -Path $resolvedManifestPath).Name
$aboutTopicPath = Join-Path -Path $resolvedHelpSourcePath -ChildPath 'about_PowerLiquid_Ast.help.md'

# When -Force is used, clear previously generated markdown so the regenerated help matches the current code comments.
if ($Force) {
    Get-ChildItem -Path $resolvedHelpSourcePath -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

Write-Verbose "Generating markdown help for module '$moduleName' into '$resolvedHelpSourcePath'."
New-MarkdownHelp -Module $moduleName -OutputFolder $resolvedHelpSourcePath -WithModulePage -Force:$Force.IsPresent | Out-Null

break

New-ExternalHelp -Path .\docs\help\ -OutputPath .\en-US\ -Verbose -ShowProgress -Force