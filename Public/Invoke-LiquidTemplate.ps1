<#
.SYNOPSIS
Renders a Liquid template.
.DESCRIPTION
Parses and renders a Liquid template against a supplied context hashtable.
PowerLiquid supports multiple dialects and host-provided extension registries
for custom tags and filters.

Before rendering, the supplied context is reduced to inert Liquid-safe data
structures. That means templates can read scalars, arrays, hashtables, and
note-property objects, but they do not execute arbitrary PowerShell script
properties or reflective object getters from untrusted input data.
.PARAMETER Template
The Liquid template source to render.
.PARAMETER Context
The root variable scope used during rendering.
.PARAMETER Dialect
The Liquid dialect to render with.
.PARAMETER IncludeRoot
The base path used when resolving include files.
.PARAMETER IncludeStack
The current include stack, primarily used internally for recursion detection.
.PARAMETER Registry
The extension registry containing custom tags and filters.
.NOTES
Custom tags and filters registered through the extension registry are trusted
host code by design. The template language itself does not compile or execute
PowerShell from template text or context data.
.OUTPUTS
System.String
.EXAMPLE
Invoke-LiquidTemplate -Template 'Hello {{ user.name }}' -Context @{ user = @{ name = 'Paul' } }
.EXAMPLE
Invoke-LiquidTemplate -Template '{% include card.html %}' -Context @{} -Dialect JekyllLiquid -IncludeRoot .\_includes
#>
function Invoke-LiquidTemplate {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template,

        [Parameter(Mandatory = $true)]
        [hashtable]$Context,

        [string]$Dialect = 'Liquid',

        [string]$IncludeRoot,

        [string[]]$IncludeStack = @(),

        [hashtable]$Registry = (New-LiquidExtensionRegistry)
    )

    assertLiquidDialect -Dialect $Dialect

    $runtime = New-LiquidRuntime -Context $Context -Dialect $Dialect -IncludeRoot $IncludeRoot -IncludeStack $IncludeStack -Registry $Registry
    $ast = ConvertTo-LiquidAst -Template $Template -Dialect $Dialect -Registry $Registry
    return ConvertFrom-LiquidNodes -Nodes $ast.Nodes -Runtime $runtime
}
