<#
.SYNOPSIS
Renders a Liquid template.
.DESCRIPTION
Parses and renders a Liquid template against a supplied context hashtable.
PowerLiquid supports multiple dialects and host-provided extension registries
for custom tags and filters. Built-in filters include string, numeric, date,
URL, and collection helpers such as sort, sort_natural, uniq, map, where, slice, strip_html,
url_encode, and url_decode.

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
.PARAMETER CurrentFilePath
The current template file path used for tags such as `include_relative`.
.PARAMETER RelativeIncludeRoot
The allowed root for `include_relative` resolution.
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
.EXAMPLE
Invoke-LiquidTemplate -Template '{% include_relative snippet.md %}' -Context @{} -Dialect JekyllLiquid -CurrentFilePath .\_posts\2026-03-29-example.md -RelativeIncludeRoot .\_posts
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

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [string]$IncludeRoot,

        [string]$CurrentFilePath,

        [string]$RelativeIncludeRoot,

        [string[]]$IncludeStack = @(),

        [hashtable]$Registry = (New-LiquidExtensionRegistry),

        [int]$RenderDepth = 0
    )

    try {
        # Validate the requested dialect before we build any runtime state.
        AssertLiquidDialect -Dialect $Dialect

        Write-Verbose "Rendering template with dialect '$Dialect'"

        # Build the isolated runtime that carries sanitized context, include settings, and host extensions.
        $runtime = newLiquidRuntime -Context $Context -Dialect $Dialect -IncludeRoot $IncludeRoot -CurrentFilePath $CurrentFilePath -RelativeIncludeRoot $RelativeIncludeRoot -IncludeStack $IncludeStack -Registry $Registry
        $runtime.RenderDepth = $RenderDepth
        Write-Verbose "Created runtime with $($Context.Count) context variables"

        # Parse the template first so render-time evaluation always works from a consistent AST shape.
        $ast = ConvertTo-LiquidAst -Template $Template -Dialect $Dialect -Registry $Registry
        Write-Verbose "Parsed AST with $($ast.Nodes.Count) nodes"

        # Render the AST against the prepared runtime and return the resulting text.
        $result = ConvertFrom-LiquidNode -Nodes $ast.Nodes -Runtime $runtime
        Write-Verbose "Rendered template successfully"

        return $result
    } catch {
        throw "Invoke-LiquidTemplate failed: $($_.Exception.Message)"
    }
}
