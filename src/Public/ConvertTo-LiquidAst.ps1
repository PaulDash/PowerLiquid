<#
.SYNOPSIS
Parses a Liquid template into an Abstract Syntax Tree (AST).
.DESCRIPTION
Tokenizes and parses a Liquid template into a structured AST object for analysis or tooling.
This is the primary PowerLiquid entry point for parse-only inspection of Liquid syntax.
Tokens and AST nodes preserve line, column, and character-index ranges for diagnostics.
Supports multiple dialects and extension registries.
.PARAMETER Template
The Liquid template source to parse.
.PARAMETER Dialect
The Liquid dialect to parse with.
.PARAMETER Registry
The extension registry containing custom tags and filters.
.PARAMETER IncludeTokens
Include the raw token stream in the AST output. Tokens also include source locations for diagnostics.
.OUTPUTS
PowerLiquid.Ast
.EXAMPLE
$ast = ConvertTo-LiquidAst -Template '{% if page.title %}{{ page.title }}{% endif %}' -Dialect JekyllLiquid
.EXAMPLE
$ast = ConvertTo-LiquidAst -Template '{{ user.name }}' -IncludeTokens
.NOTES
AST root:
- Dialect
- Nodes
- Tokens when -IncludeTokens is specified

Location object:
- StartLine
- StartColumn
- EndLine
- EndColumn
- StartIndex
- EndIndex

Common node shapes:
- Text: Type, Value, Location
- Output: Type, Expression, Location
- Assign: Type, Name, Expression, Location
- Capture: Type, Name, Nodes, Location
- If: Type, Branches, Else, Location
- Unless: Type, Condition, Nodes, Else, Location
- For: Type, VariableName, CollectionExpression, Nodes, Else, Location
- Include: Type, TargetExpression, Parameters, Location
- IncludeRelative: Type, TargetExpression, Parameters, Location
- CustomTag: Type, Name, Markup, Location

Security:
- ConvertTo-LiquidAst is parse-only.
- It does not evaluate context data, includes, filters, or custom tag handlers.
- Prefer it for editor tooling, diagnostics, linting, and safe inspection of untrusted templates.
#>
function ConvertTo-LiquidAst {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template,

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [hashtable]$Registry = (New-LiquidExtensionRegistry),

        [switch]$IncludeTokens
    )

    try {
        # Validate the dialect up front so parsing behavior stays consistent with rendering.
        AssertLiquidDialect -Dialect $Dialect

        Write-Verbose "Parsing template to AST with dialect '$Dialect'"

        # Tokenize first so the AST API can optionally return both the raw token stream and the nested node tree.
        $tokens = ConvertTo-LiquidToken -Template $Template
        Write-Verbose "Tokenized template into $($tokens.Count) tokens"

        # Parse the nested node tree and then attach token-derived source locations for diagnostics.
        $index = 0
        $nodes = parseLiquidNode -Tokens $tokens -Index ([ref]$index) -Registry $Registry
        $tokenIndex = 0
        addLiquidAstLocation -Nodes $nodes -Tokens $tokens -TokenIndex ([ref]$tokenIndex)
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
    } catch {
        throw "ConvertTo-LiquidAst failed: $($_.Exception.Message)"
    }
}