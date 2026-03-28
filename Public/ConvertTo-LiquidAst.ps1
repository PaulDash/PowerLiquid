<#
.SYNOPSIS
Parses a Liquid template into an Abstract Syntax Tree (AST).
.DESCRIPTION
Tokenizes and parses a Liquid template into a structured AST object for analysis or tooling.
Supports multiple dialects and extension registries.
.PARAMETER Template
The Liquid template source to parse.
.PARAMETER Dialect
The Liquid dialect to parse with.
.PARAMETER Registry
The extension registry containing custom tags and filters.
.PARAMETER IncludeTokens
Include the raw token stream in the AST output.
.OUTPUTS
PowerLiquid.Ast
.EXAMPLE
$ast = ConvertTo-LiquidAst -Template '{% if page.title %}{{ page.title }}{% endif %}' -Dialect JekyllLiquid
.EXAMPLE
$ast = ConvertTo-LiquidAst -Template '{{ user.name }}' -IncludeTokens
#>
function ConvertTo-LiquidAst {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template,

        [string]$Dialect = 'Liquid',

        [hashtable]$Registry = (New-LiquidExtensionRegistry),

        [switch]$IncludeTokens
    )

    assertLiquidDialect -Dialect $Dialect

    Write-Verbose "Parsing template to AST with dialect '$Dialect'"

    # Tokenize first so the AST API can optionally return both the raw token stream and the nested node tree.
    $tokens = ConvertTo-LiquidTokens -Template $Template
    Write-Verbose "Tokenized template into $($tokens.Count) tokens"

    $index = 0
    $nodes = Parse-LiquidNodes -Tokens $tokens -Index ([ref]$index) -Registry $Registry
    Write-Verbose "Parsed $($nodes.Count) AST nodes"

    # Expose a stable root object so hosts can rely on one entry shape instead of a raw node array.
    $ast = [pscustomobject]@{
        PSTypeName = 'PowerLiquid.Ast'
        Dialect    = $Dialect
        Nodes      = @($nodes)
    }

    if ($IncludeTokens) {
        Add-Member -InputObject $ast -MemberType NoteProperty -Name Tokens -Value @($tokens)
        Write-Verbose "Included token stream in AST output"
    }

    Write-Verbose "AST parsing completed successfully"
    return $ast
}
