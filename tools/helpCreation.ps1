#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ModuleManifestPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'PowerLiquid.psd1'),

    [string]$HelpSourcePath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'docs\help'),

    [switch]$Force
)

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
$aboutTopicPath = Join-Path -Path $resolvedHelpSourcePath -ChildPath 'about_PowerLiquid_AstApi.help.md'

# When -Force is used, clear previously generated markdown so the regenerated help matches the current code comments.
if ($Force) {
    Get-ChildItem -Path $resolvedHelpSourcePath -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

Write-Verbose "Generating markdown help for module '$moduleName' into '$resolvedHelpSourcePath'."
New-MarkdownHelp -Module $moduleName -OutputFolder $resolvedHelpSourcePath -WithModulePage -Force:$Force.IsPresent | Out-Null

# Create or refresh the About topic source for the AST API so New-ExternalHelp can later convert it.
$aboutTopicContent = @"
---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
title: about_PowerLiquid_AstApi
locale: en-US
help version: 0.0.1
---

# about_PowerLiquid_AstApi

## SHORT DESCRIPTION
Describes the PowerLiquid abstract syntax tree API exposed by ConvertTo-LiquidAst.

## LONG DESCRIPTION
PowerLiquid exposes a parse-first API through ConvertTo-LiquidAst.

This API is intended for:
- editors and tooling
- diagnostics
- template inspection
- host applications that need to analyze templates before rendering

ConvertTo-LiquidAst returns a PowerLiquid.Ast object. The root object contains:
- Dialect
- Nodes
- Tokens when -IncludeTokens is specified

The Nodes property is a tree of PowerShell custom objects. Each node contains a Type
property and then type-specific properties.

Current node types include:
- Text
- Output
- Assign
- Capture
- If
- Unless
- For
- Include
- CustomTag

The AST generator validates against the selected dialect. That means unsupported dialect
values fail immediately, and dialect-specific syntax such as Jekyll-style include is only
recognized when appropriate.

ConvertTo-LiquidAst is parse-only. It does not evaluate context data, filters, includes,
or custom tag handlers. If you need to inspect untrusted Liquid templates without rendering
them, prefer the AST API over the render API.

## EXAMPLES

### Example 1: Parse a template into an AST
```powershell
Import-Module .\PowerLiquid.psd1

`$template = @'
{% if page.title %}
  <h1>{{ page.title }}</h1>
{% else %}
  <h1>Untitled</h1>
{% endif %}
'@

`$ast = ConvertTo-LiquidAst -Template `$template -Dialect JekyllLiquid -IncludeTokens
`$ast.Nodes
```

### Example 2: Use the AST for diagnostics
```powershell
`$ast = ConvertTo-LiquidAst -Template '{{ user.name }}'
`$ast.Nodes | Format-Table Type, Expression
```

## NOTE
Generate this About topic into publishable help output with New-ExternalHelp after the
markdown help source in docs/help has been reviewed and finalized.
"@

Set-Content -LiteralPath $aboutTopicPath -Value $aboutTopicContent -Encoding UTF8
Write-Verbose "Wrote About topic source to '$aboutTopicPath'."

# To generate the publishable external help payload for PowerShell Gallery distribution,
# run New-ExternalHelp after reviewing the markdown in docs/help.
#
# Example:
#   Import-Module PlatyPS
#   New-Item -ItemType Directory -Path (Join-Path $moduleRoot 'en-US') -Force | Out-Null
#   New-ExternalHelp -Path $resolvedHelpSourcePath -OutputPath (Join-Path $moduleRoot 'en-US') -Force
#
# This produces:
# - PowerLiquid-help.xml
# - about_*.help.txt
#
# Include the generated en-US folder in the module package that you publish to PowerShell Gallery.

Write-Host "Prepared help source in '$resolvedHelpSourcePath'." -ForegroundColor Green
Write-Host "Review the markdown files there, then run New-ExternalHelp as documented in this script." -ForegroundColor Green
