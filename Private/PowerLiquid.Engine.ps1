Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Creates a Liquid extension registry.
.DESCRIPTION
Creates the registry object used to register host-provided custom tags and filters.
PowerLiquid keeps extensions separate by dialect so a host can opt in to different
behavior for core Liquid and Jekyll-style Liquid without loading plugins directly.
.OUTPUTS
System.Collections.Hashtable
.EXAMPLE
$registry = newLiquidExtensionRegistry
#>
function newLiquidExtensionRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Each dialect keeps separate custom tags and filters so extensions can stay dialect-specific.
    return @{
        TrustedTypes = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        Dialects = @{
            Liquid = @{
                Tags    = @{}
                Filters = @{}
            }
            JekyllLiquid = @{
                Tags    = @{}
                Filters = @{}
            }
        }
    }
}

<#
.SYNOPSIS
Registers a custom Liquid tag.
.DESCRIPTION
Adds a host-provided tag handler to an extension registry for a specific dialect.
The handler is later invoked by Invoke-LiquidTemplate when the parser encounters
the matching tag name.
.PARAMETER Registry
The extension registry created by newLiquidExtensionRegistry.
.PARAMETER Dialect
The dialect whose tag table should receive the custom tag.
.PARAMETER Name
The tag name to register.
.PARAMETER Handler
The script block that will render the custom tag.
.EXAMPLE
Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name seo -Handler { param($Invocation) '<title>Example</title>' }
#>
function Register-LiquidTag {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Handler
    )

    if (-not $Registry.Dialects.ContainsKey($Dialect)) {
        throw "Liquid dialect '$Dialect' is not supported yet."
    }

    # Custom tags plug into the parser as single inline tags such as {% seo %}.
    $Registry.Dialects[$Dialect].Tags[$Name.ToLowerInvariant()] = $Handler
}

<#
.SYNOPSIS
Registers a custom Liquid filter.
.DESCRIPTION
Adds a host-provided filter handler to an extension registry for a specific dialect.
Filter handlers participate in the normal Liquid filter pipeline during rendering.
.PARAMETER Registry
The extension registry created by newLiquidExtensionRegistry.
.PARAMETER Dialect
The dialect whose filter table should receive the custom filter.
.PARAMETER Name
The filter name to register.
.PARAMETER Handler
The script block that will run for the custom filter.
.EXAMPLE
Register-LiquidFilter -Registry $registry -Dialect Liquid -Name shout -Handler { param($Value) ([string]$Value).ToUpperInvariant() }
#>
function Register-LiquidFilter {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Handler
    )

    if (-not $Registry.Dialects.ContainsKey($Dialect)) {
        throw "Liquid dialect '$Dialect' is not supported yet."
    }

    # Custom filters join the normal filter pipeline and can be targeted to one dialect.
    $Registry.Dialects[$Dialect].Filters[$Name.ToLowerInvariant()] = $Handler
}

<#
.SYNOPSIS
Registers a trusted CLR type for object-property access.
.DESCRIPTION
By default, PowerLiquid sanitizes host-provided data down to inert scalars,
collections, hashtables, and note-property objects. If a host application wants
to expose a specific CLR type's public properties to templates, it must opt in
explicitly by registering that type as trusted.

This keeps untrusted input safe by default while still allowing trusted host
models, such as strongly-typed document objects, to participate in templates.
.PARAMETER Registry
The extension registry created by newLiquidExtensionRegistry.
.PARAMETER TypeName
The CLR type name to trust. Both full names and short names are matched.
.EXAMPLE
Register-LiquidTrustedType -Registry $registry -TypeName HydeDocument
#>
function Register-LiquidTrustedType {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [string]$TypeName
    )

    if (-not $Registry.ContainsKey('TrustedTypes') -or $null -eq $Registry.TrustedTypes) {
        $Registry.TrustedTypes = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    }

    [void]$Registry.TrustedTypes.Add($TypeName)
}

function AssertLiquidDialect {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid'
    )

    # Keep dialect validation in one place so rendering and AST generation follow the same rules.
    switch ($Dialect) {
        'Liquid' { }
        'JekyllLiquid' { }
        default {
            throw "Liquid dialect '$Dialect' is not supported yet."
        }
    }
}

function TestLiquidTrustedType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        $Value,

        [hashtable]$Registry
    )

    if ($null -eq $Value -or $null -eq $Registry -or -not $Registry.ContainsKey('TrustedTypes') -or $null -eq $Registry.TrustedTypes) {
        return $false
    }

    $type = $Value.GetType()
    return ($Registry.TrustedTypes.Contains($type.FullName) -or $Registry.TrustedTypes.Contains($type.Name))
}

function ConvertToLiquidSafeScalar {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        $Value
    )

    # Scalar values can be used directly because reading them later does not require reflective property access.
    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string] -or
        $Value -is [char] -or
        $Value -is [bool] -or
        $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64] -or
        $Value -is [single] -or
        $Value -is [double] -or
        $Value -is [decimal] -or
        $Value -is [datetime] -or
        $Value -is [timespan] -or
        $Value -is [guid]) {
        return $Value
    }

    return $null
}

function ConvertToLiquidSafeValue {
    [CmdletBinding()]
    [OutputType([hashtable], [object[]], [pscustomobject], [string], [char], [bool], [byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64], [single], [double], [decimal], [datetime], [timespan], [guid])]
    param(
        $Value,

        [hashtable]$Registry
    )

    # Reduce host-provided data to inert structures so template evaluation cannot trigger arbitrary property getters.
    $scalarValue = ConvertToLiquidSafeScalar -Value $Value
    if ($null -ne $scalarValue -or $null -eq $Value) {
        return $scalarValue
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $safeTable = @{}
        foreach ($key in $Value.Keys) {
            $safeTable[[string]$key] = ConvertToLiquidSafeValue -Value $Value[$key] -Registry $Registry
        }

        return $safeTable
    }

    if (TestLiquidTrustedType -Value $Value -Registry $Registry) {
        $safeTable = @{}
        foreach ($property in @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @('Property', 'NoteProperty') })) {
            $safeTable[[string]$property.Name] = ConvertToLiquidSafeValue -Value $property.Value -Registry $Registry
        }

        return [pscustomobject]$safeTable
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $safeItems = New-Object System.Collections.ArrayList
        foreach ($item in $Value) {
            [void]$safeItems.Add((ConvertToLiquidSafeValue -Value $item -Registry $Registry))
        }

        return ,@($safeItems.ToArray())
    }

    if ($Value -is [pscustomobject]) {
        $noteProperties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
        if ($noteProperties.Count -eq 0) {
            return $null
        }

        $safeTable = @{}
        foreach ($property in $noteProperties) {
            $safeTable[[string]$property.Name] = ConvertToLiquidSafeValue -Value $property.Value -Registry $Registry
        }

        return $safeTable
    }

    # Unsupported objects are intentionally collapsed so template access never invokes arbitrary CLR or script-backed properties.
    return $null
}

function Split-LiquidDelimitedString {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(Mandatory = $true)]
        [char]$Delimiter
    )

    # Liquid expressions reuse a few delimiter-separated forms, but delimiters inside quotes or parentheses should be ignored.
    $segments = New-Object System.Collections.ArrayList
    $builder = New-Object System.Text.StringBuilder
    $inSingleQuote = $false
    $inDoubleQuote = $false
    $parenDepth = 0

    foreach ($character in $InputText.ToCharArray()) {
        switch ($character) {
            "'" {
                if (-not $inDoubleQuote) {
                    $inSingleQuote = -not $inSingleQuote
                }
                [void]$builder.Append($character)
                continue
            }
            '"' {
                if (-not $inSingleQuote) {
                    $inDoubleQuote = -not $inDoubleQuote
                }
                [void]$builder.Append($character)
                continue
            }
            '(' {
                if (-not $inSingleQuote -and -not $inDoubleQuote) {
                    $parenDepth++
                }
                [void]$builder.Append($character)
                continue
            }
            ')' {
                if (-not $inSingleQuote -and -not $inDoubleQuote) {
                    $parenDepth--
                }
                [void]$builder.Append($character)
                continue
            }
            default {
                if (($character -eq $Delimiter) -and -not $inSingleQuote -and -not $inDoubleQuote -and $parenDepth -eq 0) {
                    [void]$segments.Add($builder.ToString())
                    [void]$builder.Clear()
                    continue
                }

                [void]$builder.Append($character)
            }
        }
    }

    [void]$segments.Add($builder.ToString())
    return ,$segments.ToArray()
}

function getLiquidAdvancedTextPosition {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$StartLine,

        [Parameter(Mandatory = $true)]
        [int]$StartColumn
    )

    # Walk a text span once so tokenization can stamp line and column ranges without re-scanning the full template.
    $line = $StartLine
    $column = $StartColumn
    foreach ($character in $Text.ToCharArray()) {
        if ($character -eq "`n") {
            $line++
            $column = 1
            continue
        }

        $column++
    }

    return @{
        Line   = $line
        Column = $column
    }
}

function newLiquidSourceLocation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$StartIndex,

        [Parameter(Mandatory = $true)]
        [int]$StartLine,

        [Parameter(Mandatory = $true)]
        [int]$StartColumn,

        [Parameter(Mandatory = $true)]
        [int]$EndIndex,

        [Parameter(Mandatory = $true)]
        [int]$EndLine,

        [Parameter(Mandatory = $true)]
        [int]$EndColumn
    )

    # Keep source locations in one consistent shape so tokens and AST nodes report the same diagnostics contract.
    return @{
        StartIndex  = $StartIndex
        StartLine   = $StartLine
        StartColumn = $StartColumn
        EndIndex    = $EndIndex
        EndLine     = $EndLine
        EndColumn   = $EndColumn
    }
}

function getLiquidTokenLocation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        $Token
    )

    return newLiquidSourceLocation -StartIndex $Token.StartIndex -StartLine $Token.StartLine -StartColumn $Token.StartColumn -EndIndex $Token.EndIndex -EndLine $Token.EndLine -EndColumn $Token.EndColumn
}
function ConvertTo-LiquidToken {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template
    )

    # Tokenize the template into plain text, output blocks, and tag blocks while preserving exact source positions.
    $tokens = New-Object System.Collections.ArrayList
    $pattern = '\{\{[-]?(.*?)[-]?\}\}|\{%-?(.*?)-?%\}'
    $regexMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $Template,
        $pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    $position = 0
    $line = 1
    $column = 1
    foreach ($match in $regexMatches) {
        if ($match.Index -gt $position) {
            $text = $Template.Substring($position, $match.Index - $position)
            $textEnd = getLiquidAdvancedTextPosition -Text $text -StartLine $line -StartColumn $column
            [void]$tokens.Add([pscustomobject]@{
                Type        = 'Text'
                Raw         = $text
                Value       = $text
                StartIndex  = $position
                StartLine   = $line
                StartColumn = $column
                EndIndex    = $match.Index
                EndLine     = $textEnd.Line
                EndColumn   = $textEnd.Column
                Location    = (newLiquidSourceLocation -StartIndex $position -StartLine $line -StartColumn $column -EndIndex $match.Index -EndLine $textEnd.Line -EndColumn $textEnd.Column)
            })
            $line = $textEnd.Line
            $column = $textEnd.Column
        }

        $matchEnd = getLiquidAdvancedTextPosition -Text $match.Value -StartLine $line -StartColumn $column
        $tokenType = if ($match.Value.StartsWith('{{')) { 'Output' } else { 'Tag' }
        $tokenValue = if ($tokenType -eq 'Output') { $match.Groups[1].Value.Trim() } else { $match.Groups[2].Value.Trim() }
        [void]$tokens.Add([pscustomobject]@{
            Type        = $tokenType
            Raw         = $match.Value
            Value       = $tokenValue
            StartIndex  = $match.Index
            StartLine   = $line
            StartColumn = $column
            EndIndex    = $match.Index + $match.Length
            EndLine     = $matchEnd.Line
            EndColumn   = $matchEnd.Column
            Location    = (newLiquidSourceLocation -StartIndex $match.Index -StartLine $line -StartColumn $column -EndIndex ($match.Index + $match.Length) -EndLine $matchEnd.Line -EndColumn $matchEnd.Column)
        })

        $position = $match.Index + $match.Length
        $line = $matchEnd.Line
        $column = $matchEnd.Column
    }

    if ($position -lt $Template.Length) {
        $text = $Template.Substring($position)
        $textEnd = getLiquidAdvancedTextPosition -Text $text -StartLine $line -StartColumn $column
        [void]$tokens.Add([pscustomobject]@{
            Type        = 'Text'
            Raw         = $text
            Value       = $text
            StartIndex  = $position
            StartLine   = $line
            StartColumn = $column
            EndIndex    = $Template.Length
            EndLine     = $textEnd.Line
            EndColumn   = $textEnd.Column
            Location    = (newLiquidSourceLocation -StartIndex $position -StartLine $line -StartColumn $column -EndIndex $Template.Length -EndLine $textEnd.Line -EndColumn $textEnd.Column)
        })
    }

    return ,$tokens.ToArray()
}
function getLiquidTagPart {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markup
    )

    # Split a tag into its name and the remaining markup payload.
    $trimmedMarkup = $Markup.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedMarkup)) {
        return [pscustomobject]@{
            Name   = ''
            Markup = ''
        }
    }

    $parts = $trimmedMarkup -split '\s+', 2
    return [pscustomobject]@{
        Name   = $parts[0]
        Markup = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    }
}

function Split-LiquidWhitespaceToken {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputText
    )

    # Include-style tags need whitespace tokenization that keeps quoted strings intact.
    $regexMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $InputText,
        '(?:"[^"]*"|''[^'']*''|\S+)'
    )

    return ,@($regexMatches | ForEach-Object { $_.Value })
}

function parseLiquidIncludeMarkup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markup
    )

    # Include accepts a target plus optional key=value parameters.
    $tokens = Split-LiquidWhitespaceToken -InputText $Markup
    if ($tokens.Count -eq 0) {
        throw "Liquid include tag is invalid: '$Markup'."
    }

    $parameters = New-Object System.Collections.ArrayList
    foreach ($token in @($tokens | Select-Object -Skip 1)) {
        if ($token -notmatch '^([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*(.+)$') {
            throw "Liquid include parameter is invalid: '$token'."
        }

        [void]$parameters.Add([pscustomobject]@{
            Name       = $matches[1]
            Expression = $matches[2]
        })
    }

    return [pscustomobject]@{
        TargetExpression = $tokens[0]
        Parameters       = @($parameters.ToArray())
    }
}

function parseLiquidForMarkup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markup
    )

    # Basic for loops follow the Liquid shape: "item in collection".
    if ($Markup -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+)$') {
        throw "Liquid for tag is invalid: '$Markup'."
    }

    return [pscustomobject]@{
        VariableName         = $matches[1]
        CollectionExpression = $matches[2]
    }
}

function parseLiquidCycleMarkup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markup
    )

    # Cycle optionally accepts a group expression before a colon and then one or more expressions.
    $groupExpression = $null
    $valueMarkup = $Markup.Trim()
    $colonParts = Split-LiquidDelimitedString -InputText $valueMarkup -Delimiter ':'
    if ($colonParts.Count -gt 1) {
        $groupExpression = [string]$colonParts[0]
        $valueMarkup = (($colonParts | Select-Object -Skip 1) -join ':')
    }

    $valueExpressions = @()
    foreach ($segment in (Split-LiquidDelimitedString -InputText ([string]$valueMarkup) -Delimiter ',')) {
        $trimmedSegment = ([string]$segment).Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmedSegment)) {
            $valueExpressions += $trimmedSegment
        }
    }

    if ($valueExpressions.Count -eq 0) {
        throw "Liquid cycle tag is invalid: '$Markup'."
    }

    return [pscustomobject]@{
        GroupExpression  = if ([string]::IsNullOrWhiteSpace($groupExpression)) { $null } else { $groupExpression.Trim() }
        ValueExpressions = $valueExpressions
    }
}

function parseLiquidTablerowMarkup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markup
    )

    if ($Markup -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+)$') {
        throw "Liquid tablerow tag is invalid: '$Markup'."
    }

    $variableName = $matches[1]
    $remainder = $matches[2]
    if ($remainder -notmatch '^(.*?)(?:\s+cols\s*:\s*(\d+))?$') {
        throw "Liquid tablerow tag is invalid: '$Markup'."
    }

    $collectionExpression = $matches[1].Trim()
    $columns = if ($matches[2]) { [int]$matches[2] } else { 1 }
    if ([string]::IsNullOrWhiteSpace($collectionExpression) -or $columns -lt 1) {
        throw "Liquid tablerow tag is invalid: '$Markup'."
    }

    return [pscustomobject]@{
        VariableName         = $variableName
        CollectionExpression = $collectionExpression
        Columns              = $columns
    }
}

function parseLiquidNode {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Tokens,

        [Parameter(Mandatory = $true)]
        [ref]$Index,

        [string[]]$EndTags = @(),

        [hashtable]$Registry
    )

    # Convert the flat token stream into a simple AST with nested control-flow nodes.
    $nodes = New-Object System.Collections.ArrayList

    while ($Index.Value -lt $Tokens.Count) {
        $token = $Tokens[$Index.Value]

        if ($token.Type -eq 'Text') {
            [void]$nodes.Add([pscustomobject]@{ Type = 'Text'; Value = $token.Value })
            $Index.Value++
            continue
        }

        if ($token.Type -eq 'Output') {
            [void]$nodes.Add([pscustomobject]@{ Type = 'Output'; Expression = $token.Value })
            $Index.Value++
            continue
        }

        $tagParts = getLiquidTagPart -Markup $token.Value
        if ($EndTags -contains $tagParts.Name) {
            break
        }

        switch ($tagParts.Name) {
            'assign' {
                if ($tagParts.Markup -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
                    throw "Liquid assign tag is invalid: '$($token.Value)'."
                }

                [void]$nodes.Add([pscustomobject]@{
                    Type       = 'Assign'
                    Name       = $matches[1]
                    Expression = $matches[2]
                })
                $Index.Value++
            }
            'capture' {
                if ($tagParts.Markup -notmatch '^([A-Za-z_][A-Za-z0-9_]*)$') {
                    throw "Liquid capture tag is invalid: '$($token.Value)'."
                }

                $captureName = $matches[1]
                $Index.Value++
                $bodyNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('endcapture') -Registry $Registry
                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid capture tag '$captureName' is missing endcapture."
                }

                $Index.Value++
                [void]$nodes.Add([pscustomobject]@{
                    Type  = 'Capture'
                    Name  = $captureName
                    Nodes = $bodyNodes
                })
            }
            'if' {
                $branches = New-Object System.Collections.ArrayList
                $condition = $tagParts.Markup
                $Index.Value++

                while ($true) {
                    $branchNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('elsif', 'else', 'endif') -Registry $Registry
                    [void]$branches.Add([pscustomobject]@{
                        Condition = $condition
                        Nodes     = $branchNodes
                    })

                    if ($Index.Value -ge $Tokens.Count) {
                        throw "Liquid if tag is missing endif."
                    }

                    $nextTag = getLiquidTagPart -Markup $Tokens[$Index.Value].Value
                    switch ($nextTag.Name) {
                        'elsif' {
                            $condition = $nextTag.Markup
                            $Index.Value++
                            continue
                        }
                        'else' {
                            $Index.Value++
                            $elseNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('endif') -Registry $Registry
                            if ($Index.Value -ge $Tokens.Count) {
                                throw "Liquid if tag is missing endif."
                            }

                            $Index.Value++
                            [void]$nodes.Add([pscustomobject]@{
                                Type     = 'If'
                                Branches = $branches.ToArray()
                                Else     = $elseNodes
                            })
                            break
                        }
                        'endif' {
                            $Index.Value++
                            [void]$nodes.Add([pscustomobject]@{
                                Type     = 'If'
                                Branches = $branches.ToArray()
                                Else     = @()
                            })
                            break
                        }
                        default {
                            throw "Unexpected Liquid tag '$($nextTag.Name)' inside if."
                        }
                    }

                    break
                }
            }
            'for' {
                $forMarkup = parseLiquidForMarkup -Markup $tagParts.Markup
                $Index.Value++
                $bodyNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('else', 'endfor') -Registry $Registry
                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid for tag is missing endfor."
                }

                $nextTag = getLiquidTagPart -Markup $Tokens[$Index.Value].Value
                $elseNodes = @()
                if ($nextTag.Name -eq 'else') {
                    $Index.Value++
                    $elseNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('endfor') -Registry $Registry
                    if ($Index.Value -ge $Tokens.Count) {
                        throw "Liquid for tag is missing endfor."
                    }
                }

                $Index.Value++
                [void]$nodes.Add([pscustomobject]@{
                    Type                 = 'For'
                    VariableName         = $forMarkup.VariableName
                    CollectionExpression = $forMarkup.CollectionExpression
                    Nodes                = $bodyNodes
                    Else                 = $elseNodes
                })
            }
            'case' {
                $caseExpression = $tagParts.Markup
                $Index.Value++
                $whenBranches = New-Object System.Collections.ArrayList
                $elseNodes = @()

                :caseLoop while ($Index.Value -lt $Tokens.Count) {
                    $currentTag = getLiquidTagPart -Markup $Tokens[$Index.Value].Value
                    switch ($currentTag.Name) {
                        'when' {
                            $whenExpressions = @()
                            foreach ($segment in (Split-LiquidDelimitedString -InputText $currentTag.Markup -Delimiter ',')) {
                                $trimmedSegment = ([string]$segment).Trim()
                                if (-not [string]::IsNullOrWhiteSpace($trimmedSegment)) {
                                    $whenExpressions += $trimmedSegment
                                }
                            }
                            if ($whenExpressions.Count -eq 0) {
                                throw "Liquid case when tag is invalid: '$($Tokens[$Index.Value].Value)'."
                            }

                            $Index.Value++
                            $whenNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('when', 'else', 'endcase') -Registry $Registry
                            [void]$whenBranches.Add([pscustomobject]@{
                                Values = $whenExpressions
                                Nodes  = $whenNodes
                            })
                            continue caseLoop
                        }
                        'else' {
                            $Index.Value++
                            $elseNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('endcase') -Registry $Registry
                            if ($Index.Value -ge $Tokens.Count) {
                                throw "Liquid case tag is missing endcase."
                            }

                            $Index.Value++
                            break caseLoop
                        }
                        'endcase' {
                            $Index.Value++
                            break caseLoop
                        }
                        default {
                            throw "Liquid case tag requires when, else, or endcase tags."
                        }
                    }
                }

                [void]$nodes.Add([pscustomobject]@{
                    Type       = 'Case'
                    Expression = $caseExpression
                    Whens      = @($whenBranches.ToArray())
                    Else       = $elseNodes
                })
            }
            'cycle' {
                $cycleMarkup = parseLiquidCycleMarkup -Markup $tagParts.Markup
                [void]$nodes.Add([pscustomobject]@{
                    Type             = 'Cycle'
                    GroupExpression  = $cycleMarkup.GroupExpression
                    ValueExpressions = $cycleMarkup.ValueExpressions
                })
                $Index.Value++
            }
            'increment' {
                if ($tagParts.Markup -notmatch '^([A-Za-z_][A-Za-z0-9_]*)$') {
                    throw "Liquid increment tag is invalid: '$($token.Value)'."
                }

                [void]$nodes.Add([pscustomobject]@{
                    Type = 'Increment'
                    Name = $matches[1]
                })
                $Index.Value++
            }
            'decrement' {
                if ($tagParts.Markup -notmatch '^([A-Za-z_][A-Za-z0-9_]*)$') {
                    throw "Liquid decrement tag is invalid: '$($token.Value)'."
                }

                [void]$nodes.Add([pscustomobject]@{
                    Type = 'Decrement'
                    Name = $matches[1]
                })
                $Index.Value++
            }
            'break' {
                [void]$nodes.Add([pscustomobject]@{ Type = 'Break' })
                $Index.Value++
            }
            'continue' {
                [void]$nodes.Add([pscustomobject]@{ Type = 'Continue' })
                $Index.Value++
            }
            'tablerow' {
                $tablerowMarkup = parseLiquidTablerowMarkup -Markup $tagParts.Markup
                $Index.Value++
                $bodyNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('endtablerow') -Registry $Registry
                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid tablerow tag is missing endtablerow."
                }

                $Index.Value++
                [void]$nodes.Add([pscustomobject]@{
                    Type                 = 'Tablerow'
                    VariableName         = $tablerowMarkup.VariableName
                    CollectionExpression = $tablerowMarkup.CollectionExpression
                    Columns              = $tablerowMarkup.Columns
                    Nodes                = $bodyNodes
                })
            }
            'unless' {
                $condition = $tagParts.Markup
                $Index.Value++
                $bodyNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('else', 'endunless') -Registry $Registry
                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid unless tag is missing endunless."
                }

                $nextTag = getLiquidTagPart -Markup $Tokens[$Index.Value].Value
                $elseNodes = @()
                if ($nextTag.Name -eq 'else') {
                    $Index.Value++
                    $elseNodes = parseLiquidNode -Tokens $Tokens -Index $Index -EndTags @('endunless') -Registry $Registry
                    if ($Index.Value -ge $Tokens.Count) {
                        throw "Liquid unless tag is missing endunless."
                    }
                }

                $Index.Value++
                [void]$nodes.Add([pscustomobject]@{
                    Type      = 'Unless'
                    Condition = $condition
                    Nodes     = $bodyNodes
                    Else      = $elseNodes
                })
            }
            'comment' {
                $Index.Value++
                while ($Index.Value -lt $Tokens.Count) {
                    if ($Tokens[$Index.Value].Type -eq 'Tag' -and (getLiquidTagPart -Markup $Tokens[$Index.Value].Value).Name -eq 'endcomment') {
                        break
                    }
                    $Index.Value++
                }

                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid comment tag is missing endcomment."
                }

                $Index.Value++
            }
            'raw' {
                $Index.Value++
                $rawBuilder = New-Object System.Text.StringBuilder
                while ($Index.Value -lt $Tokens.Count) {
                    $rawToken = $Tokens[$Index.Value]
                    if ($rawToken.Type -eq 'Tag' -and (getLiquidTagPart -Markup $rawToken.Value).Name -eq 'endraw') {
                        break
                    }

                    [void]$rawBuilder.Append($rawToken.Raw)
                    $Index.Value++
                }

                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid raw tag is missing endraw."
                }

                $Index.Value++
                [void]$nodes.Add([pscustomobject]@{
                    Type  = 'Text'
                    Value = $rawBuilder.ToString()
                })
            }
            'include' {
                $includeMarkup = parseLiquidIncludeMarkup -Markup $tagParts.Markup
                [void]$nodes.Add([pscustomobject]@{
                    Type             = 'Include'
                    TargetExpression = $includeMarkup.TargetExpression
                    Parameters       = $includeMarkup.Parameters
                })
                $Index.Value++
            }
            'include_relative' {
                $includeMarkup = parseLiquidIncludeMarkup -Markup $tagParts.Markup
                [void]$nodes.Add([pscustomobject]@{
                    Type             = 'IncludeRelative'
                    TargetExpression = $includeMarkup.TargetExpression
                    Parameters       = $includeMarkup.Parameters
                })
                $Index.Value++
            }
            # TODO: Add Liquid tag support for echo.
            # TODO: Add Liquid tag support for render.
            '' {
                $Index.Value++
            }
            default {
                $customTagHandler = $null
                if ($null -ne $Registry -and
                    $Registry.ContainsKey('Dialects') -and
                    $Registry.Dialects.ContainsKey('Liquid') -and
                    $Registry.Dialects['Liquid'].Tags.ContainsKey($tagParts.Name.ToLowerInvariant())) {
                    $customTagHandler = $Registry.Dialects['Liquid'].Tags[$tagParts.Name.ToLowerInvariant()]
                }

                if ($null -eq $customTagHandler -and
                    $null -ne $Registry -and
                    $Registry.ContainsKey('Dialects') -and
                    $Registry.Dialects.ContainsKey('JekyllLiquid') -and
                    $Registry.Dialects['JekyllLiquid'].Tags.ContainsKey($tagParts.Name.ToLowerInvariant())) {
                    $customTagHandler = $Registry.Dialects['JekyllLiquid'].Tags[$tagParts.Name.ToLowerInvariant()]
                }

                if ($null -ne $customTagHandler) {
                    [void]$nodes.Add([pscustomobject]@{
                        Type   = 'CustomTag'
                        Name   = $tagParts.Name
                        Markup = $tagParts.Markup
                    })
                    $Index.Value++
                    continue
                }

                throw "Liquid tag '$($tagParts.Name)' is not supported."
            }
        }
    }

    return ,$nodes.ToArray()
}

function addLiquidAstLocation {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Nodes,

        [Parameter(Mandatory = $true)]
        [object[]]$Tokens,

        [Parameter(Mandatory = $true)]
        [ref]$TokenIndex
    )

    foreach ($node in $Nodes) {
        switch ($node.Type) {
            'Text' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Output' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Assign' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Include' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'IncludeRelative' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Cycle' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Increment' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Decrement' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Break' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Continue' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'CustomTag' { $token = $Tokens[$TokenIndex.Value]; Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (getLiquidTokenLocation -Token $token) -Force; $TokenIndex.Value++ }
            'Capture' {
                $startToken = $Tokens[$TokenIndex.Value]
                $TokenIndex.Value++
                addLiquidAstLocation -Nodes $node.Nodes -Tokens $Tokens -TokenIndex $TokenIndex
                $endToken = $Tokens[$TokenIndex.Value]
                Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (newLiquidSourceLocation -StartIndex $startToken.StartIndex -StartLine $startToken.StartLine -StartColumn $startToken.StartColumn -EndIndex $endToken.EndIndex -EndLine $endToken.EndLine -EndColumn $endToken.EndColumn) -Force
                $TokenIndex.Value++
            }
            'If' {
                $startToken = $Tokens[$TokenIndex.Value]
                $TokenIndex.Value++
                $branchIndex = 0
                foreach ($branch in $node.Branches) {
                    addLiquidAstLocation -Nodes $branch.Nodes -Tokens $Tokens -TokenIndex $TokenIndex
                    if ($branchIndex + 1 -lt $node.Branches.Count) { $TokenIndex.Value++ }
                    $branchIndex++
                }
                if ($node.Else.Count -gt 0) { $TokenIndex.Value++; addLiquidAstLocation -Nodes $node.Else -Tokens $Tokens -TokenIndex $TokenIndex }
                $endToken = $Tokens[$TokenIndex.Value]
                Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (newLiquidSourceLocation -StartIndex $startToken.StartIndex -StartLine $startToken.StartLine -StartColumn $startToken.StartColumn -EndIndex $endToken.EndIndex -EndLine $endToken.EndLine -EndColumn $endToken.EndColumn) -Force
                $TokenIndex.Value++
            }
            'For' {
                $startToken = $Tokens[$TokenIndex.Value]
                $TokenIndex.Value++
                addLiquidAstLocation -Nodes $node.Nodes -Tokens $Tokens -TokenIndex $TokenIndex
                if ($node.Else.Count -gt 0) { $TokenIndex.Value++; addLiquidAstLocation -Nodes $node.Else -Tokens $Tokens -TokenIndex $TokenIndex }
                $endToken = $Tokens[$TokenIndex.Value]
                Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (newLiquidSourceLocation -StartIndex $startToken.StartIndex -StartLine $startToken.StartLine -StartColumn $startToken.StartColumn -EndIndex $endToken.EndIndex -EndLine $endToken.EndLine -EndColumn $endToken.EndColumn) -Force
                $TokenIndex.Value++
            }
            'Case' {
                $startToken = $Tokens[$TokenIndex.Value]
                $TokenIndex.Value++
                for ($whenIndex = 0; $whenIndex -lt $node.Whens.Count; $whenIndex++) {
                    addLiquidAstLocation -Nodes $node.Whens[$whenIndex].Nodes -Tokens $Tokens -TokenIndex $TokenIndex
                    if ($whenIndex + 1 -lt $node.Whens.Count) { $TokenIndex.Value++ }
                }
                if ($node.Else.Count -gt 0) { $TokenIndex.Value++; addLiquidAstLocation -Nodes $node.Else -Tokens $Tokens -TokenIndex $TokenIndex }
                $endToken = $Tokens[$TokenIndex.Value]
                Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (newLiquidSourceLocation -StartIndex $startToken.StartIndex -StartLine $startToken.StartLine -StartColumn $startToken.StartColumn -EndIndex $endToken.EndIndex -EndLine $endToken.EndLine -EndColumn $endToken.EndColumn) -Force
                $TokenIndex.Value++
            }
            'Tablerow' {
                $startToken = $Tokens[$TokenIndex.Value]
                $TokenIndex.Value++
                addLiquidAstLocation -Nodes $node.Nodes -Tokens $Tokens -TokenIndex $TokenIndex
                $endToken = $Tokens[$TokenIndex.Value]
                Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (newLiquidSourceLocation -StartIndex $startToken.StartIndex -StartLine $startToken.StartLine -StartColumn $startToken.StartColumn -EndIndex $endToken.EndIndex -EndLine $endToken.EndLine -EndColumn $endToken.EndColumn) -Force
                $TokenIndex.Value++
            }
            'Unless' {
                $startToken = $Tokens[$TokenIndex.Value]
                $TokenIndex.Value++
                addLiquidAstLocation -Nodes $node.Nodes -Tokens $Tokens -TokenIndex $TokenIndex
                if ($node.Else.Count -gt 0) { $TokenIndex.Value++; addLiquidAstLocation -Nodes $node.Else -Tokens $Tokens -TokenIndex $TokenIndex }
                $endToken = $Tokens[$TokenIndex.Value]
                Add-Member -InputObject $node -MemberType NoteProperty -Name Location -Value (newLiquidSourceLocation -StartIndex $startToken.StartIndex -StartLine $startToken.StartLine -StartColumn $startToken.StartColumn -EndIndex $endToken.EndIndex -EndLine $endToken.EndLine -EndColumn $endToken.EndColumn) -Force
                $TokenIndex.Value++
            }
            default { throw "AST location assignment does not support node type '$($node.Type)'." }
        }
    }
}
function parseLiquidTemplate {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template,

        [hashtable]$Registry
    )

    # Parsing starts by tokenizing the template, then building nested nodes from those tokens.
    $tokens = ConvertTo-LiquidToken -Template $Template
    $index = 0
    $nodes = parseLiquidNode -Tokens $tokens -Index ([ref]$index) -Registry $Registry
    $tokenIndex = 0
    addLiquidAstLocation -Nodes $nodes -Tokens $tokens -TokenIndex ([ref]$tokenIndex)
    return $nodes
}
function Get-LiquidRuntimeValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        $Value,

        [Parameter(Mandatory = $true)]
        [string]$MemberName
    )

    if ($null -eq $Value) {
        return $null
    }

    # Many PowerShell collection types expose Count/Length as properties even when interface checks are inconsistent.
    switch ($MemberName.ToLowerInvariant()) {
        'size' {
            if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                return @($Value).Count
            }

            $countProperty = $Value.PSObject.Properties | Where-Object { $_.Name -in @('Count', 'Length') } | Select-Object -First 1
            if ($null -ne $countProperty) {
                return $countProperty.Value
            }
        }
        'first' {
            if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                $items = @($Value)
                if ($items.Count -gt 0) {
                    return $items[0]
                }

                return $null
            }
        }
        'last' {
            if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                $items = @($Value)
                if ($items.Count -gt 0) {
                    return $items[$items.Count - 1]
                }

                return $null
            }
        }
    }

    # Resolve one member access against the current value, covering hashtables, lists, strings, and objects.
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -ieq $MemberName) {
                Write-Output -InputObject $Value[$key] -NoEnumerate
                return
            }
        }

        return $null
    }

    if ($Value -is [System.Collections.IList]) {
        switch ($MemberName.ToLowerInvariant()) {
            'size' { return $Value.Count }
            'first' {
                if ($Value.Count -gt 0) {
                    Write-Output -InputObject $Value[0] -NoEnumerate
                    return
                }

                return $null
            }
            'last' {
                if ($Value.Count -gt 0) {
                    Write-Output -InputObject $Value[$Value.Count - 1] -NoEnumerate
                    return
                }

                return $null
            }
            default {
                if ($MemberName -match '^\d+$') {
                    $index = [int]$MemberName
                    if ($index -lt $Value.Count) {
                        Write-Output -InputObject $Value[$index] -NoEnumerate
                        return
                    }

                    return $null
                }
            }
        }
    }

    if ($Value -is [string]) {
        switch ($MemberName.ToLowerInvariant()) {
            'size' { return $Value.Length }
            'first' { return if ($Value.Length -gt 0) { $Value.Substring(0, 1) } else { $null } }
            'last' { return if ($Value.Length -gt 0) { $Value.Substring($Value.Length - 1, 1) } else { $null } }
        }
    }

    $property = $Value.PSObject.Properties |
        Where-Object { ($_.MemberType -eq 'NoteProperty') -and ($_.Name -ieq $MemberName) } |
        Select-Object -First 1
    if ($null -ne $property) {
        Write-Output -InputObject $property.Value -NoEnumerate
        return
    }

    return $null
}

function Resolve-LiquidVariable {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Liquid looks up dotted paths by walking the current scope stack, then each nested member.
    $segments = $Path.Split('.')
    foreach ($scope in $Runtime.Scopes) {
        $value = $null
        $foundValue = $false

        if ($scope -is [System.Collections.IDictionary]) {
            foreach ($key in $scope.Keys) {
                if ([string]$key -ieq $segments[0]) {
                    $value = $scope[$key]
                    $foundValue = $true
                    break
                }
            }
        } else {
            $property = $scope.PSObject.Properties |
                Where-Object { ($_.MemberType -eq 'NoteProperty') -and ($_.Name -ieq $segments[0]) } |
                Select-Object -First 1
            if ($null -ne $property) {
                $value = $property.Value
                $foundValue = $true
            }
        }

        if (-not $foundValue) {
            continue
        }

        for ($index = 1; $index -lt $segments.Length; $index++) {
            if ($null -eq $value) {
                break
            }

            $memberName = $segments[$index]
            $handledMember = $false
            switch ($memberName.ToLowerInvariant()) {
                'size' {
                    if ($value -is [string]) {
                        $value = $value.Length
                        $handledMember = $true
                    } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                        $value = @($value).Count
                        $handledMember = $true
                    }
                }
                'first' {
                    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string] -and $value -isnot [System.Collections.IDictionary]) {
                        $items = @($value)
                        if ($items.Count -gt 0) {
                            $value = $items[0]
                        } else {
                            $value = $null
                        }
                        $handledMember = $true
                    }
                }
                'last' {
                    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string] -and $value -isnot [System.Collections.IDictionary]) {
                        $items = @($value)
                        if ($items.Count -gt 0) {
                            $value = $items[$items.Count - 1]
                        } else {
                            $value = $null
                        }
                        $handledMember = $true
                    }
                }
            }

            if ($handledMember) {
                continue
            }

            $resolvedMemberValue = $null
            $resolvedMember = $false

            if ($value -is [System.Collections.IDictionary]) {
                foreach ($key in $value.Keys) {
                    if ([string]$key -ieq $memberName) {
                        $resolvedMemberValue = $value[$key]
                        $resolvedMember = $true
                        break
                    }
                }
            } elseif ($value -is [System.Collections.IList] -and $memberName -match '^\d+$') {
                $memberIndex = [int]$memberName
                if ($memberIndex -lt $value.Count) {
                    $resolvedMemberValue = $value[$memberIndex]
                    $resolvedMember = $true
                }
            } else {
                $property = $value.PSObject.Properties |
                    Where-Object { ($_.MemberType -eq 'NoteProperty') -and ($_.Name -ieq $memberName) } |
                    Select-Object -First 1
                if ($null -ne $property) {
                    $resolvedMemberValue = $property.Value
                    $resolvedMember = $true
                }
            }

            if (-not $resolvedMember) {
                $value = $null
                break
            }

            $value = $resolvedMemberValue
        }

        if ($null -ne $value) {
            if (($value -is [System.Collections.IEnumerable]) -and
                ($value -isnot [string]) -and
                ($value -isnot [System.Collections.IDictionary]) -and
                (@($value).Count -eq 1)) {
                Write-Output -InputObject $value -NoEnumerate
                return
            }

            return $value
        }
    }

    return $null
}

function ConvertTo-LiquidLiteralValue {
    [CmdletBinding()]
    [OutputType([string], [bool], [int32], [double])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expression,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Expressions can be quoted strings, booleans, null-ish values, numbers, or variable paths.
    $trimmedExpression = $Expression.Trim()
    if ($trimmedExpression -match "^'(.*)'$" -or $trimmedExpression -match '^"(.*)"$') {
        return $matches[1]
    }

    switch ($trimmedExpression.ToLowerInvariant()) {
        'true' { return $true }
        'false' { return $false }
        'nil' { return $null }
        'null' { return $null }
        'empty' { return '' }
    }

    if ($trimmedExpression -match '^-?\d+$') {
        return [int]$trimmedExpression
    }

    if ($trimmedExpression -match '^-?\d+\.\d+$') {
        return [double]$trimmedExpression
    }

    return Resolve-LiquidVariable -Runtime $Runtime -Path $trimmedExpression
}

function Resolve-LiquidSortValue {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        $Value,

        [string]$PropertyName
    )

    if ([string]::IsNullOrWhiteSpace($PropertyName)) {
        return $Value
    }

    $currentValue = $Value
    foreach ($segment in $PropertyName.Split('.')) {
        if ($null -eq $currentValue) {
            return $null
        }

        $currentValue = Get-LiquidRuntimeValue -Value $currentValue -MemberName $segment
    }

    return $currentValue
}

function ConvertTo-LiquidNaturalSortKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $Value
    )

    $text = ConvertTo-LiquidOutputString -Value $Value
    $normalized = $text.ToLowerInvariant()
    return [System.Text.RegularExpressions.Regex]::Replace(
        $normalized,
        '\d+',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($Match)
            $Match.Value.PadLeft(20, '0')
        }
    )
}

function ConvertTo-LiquidOutputString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $Value
    )

    # Rendering normalizes nulls to empty strings and flattens simple enumerable values.
    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return (($Value | ForEach-Object { ConvertTo-LiquidOutputString -Value $_ }) -join '')
    }

    return [string]$Value
}

function ConvertTo-LiquidNumericValue {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        $Value
    )

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        return [double]$Value
    }

    if ($Value -is [string]) {
        $trimmed = $Value.Trim()
        $number = 0.0
        if ([double]::TryParse($trimmed, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
            return $number
        }
    }

    if ($null -eq $Value) {
        return 0
    }

    throw "Liquid value '$Value' is not a number."
}

function Test-LiquidTruthy {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        $Value
    )

    # Liquid truthiness is intentionally narrower than PowerShell truthiness.
    return (-not ($null -eq $Value -or $Value -eq $false))
}

function getLiquidDialectExtension {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [hashtable]$Registry,
        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid'
    )

    if ($null -eq $Registry -or -not $Registry.ContainsKey('Dialects')) {
        return @()
    }

    $extensions = New-Object System.Collections.ArrayList
    if ($Registry.Dialects.ContainsKey('Liquid')) {
        [void]$extensions.Add($Registry.Dialects['Liquid'])
    }

    if (($Dialect -ne 'Liquid') -and $Registry.Dialects.ContainsKey($Dialect)) {
        [void]$extensions.Add($Registry.Dialects[$Dialect])
    }

    return @($extensions.ToArray())
}

function Get-LiquidCustomFilter {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [hashtable]$Runtime
    )

    foreach ($dialectExtensions in getLiquidDialectExtension -Registry $Runtime.Registry -Dialect $Runtime.Dialect) {
        if ($dialectExtensions.Filters.ContainsKey($Name.ToLowerInvariant())) {
            return $dialectExtensions.Filters[$Name.ToLowerInvariant()]
        }
    }

    return $null
}

function Get-LiquidCustomTag {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [hashtable]$Runtime
    )

    foreach ($dialectExtensions in getLiquidDialectExtension -Registry $Runtime.Registry -Dialect $Runtime.Dialect) {
        if ($dialectExtensions.Tags.ContainsKey($Name.ToLowerInvariant())) {
            return $dialectExtensions.Tags[$Name.ToLowerInvariant()]
        }
    }

    return $null
}

function newLiquidExtensionInvocation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Extension handlers get a small helper surface instead of reaching into module internals directly.
    return @{
        Runtime = $Runtime
        Helpers = @{
            ResolveExpression = {
                param([string]$Expression)
                Resolve-LiquidExpression -Expression $Expression -Runtime $Runtime
            }
            ResolveVariable = {
                param([string]$Path)
                Resolve-LiquidVariable -Runtime $Runtime -Path $Path
            }
            ConvertToString = {
                param($Value)
                ConvertTo-LiquidOutputString -Value $Value
            }
        }
    }
}

function Invoke-LiquidFilter {
    [CmdletBinding()]
    [OutputType([string], [object[]], [hashtable], [pscustomobject], [bool], [int32], [double])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        $InputObject,

        [object[]]$Arguments = @(),

        [hashtable]$Runtime
    )

    # Start with a small filter surface that is useful in layouts and easy to extend later.
    $dialect = if ($null -ne $Runtime -and $Runtime.ContainsKey('Dialect')) { $Runtime.Dialect } else { 'Liquid' }
    $customFilter = if ($null -ne $Runtime) { Get-LiquidCustomFilter -Name $Name -Runtime $Runtime } else { $null }
    if ($null -ne $customFilter) {
        $invocation = newLiquidExtensionInvocation -Runtime $Runtime
        $invocation['Name'] = $Name
        $invocation['InputObject'] = $InputObject
        $invocation['Arguments'] = $Arguments
        return (& $customFilter $invocation)
    }

    switch ($Name.ToLowerInvariant()) {
        'append' { return (ConvertTo-LiquidOutputString -Value $InputObject) + (ConvertTo-LiquidOutputString -Value $Arguments[0]) }
        'prepend' { return (ConvertTo-LiquidOutputString -Value $Arguments[0]) + (ConvertTo-LiquidOutputString -Value $InputObject) }
        'upcase' { return (ConvertTo-LiquidOutputString -Value $InputObject).ToUpperInvariant() }
        'downcase' { return (ConvertTo-LiquidOutputString -Value $InputObject).ToLowerInvariant() }
        'strip' { return (ConvertTo-LiquidOutputString -Value $InputObject).Trim() }
        'lstrip' { return (ConvertTo-LiquidOutputString -Value $InputObject).TrimStart() }
        'rstrip' { return (ConvertTo-LiquidOutputString -Value $InputObject).TrimEnd() }
        'default' {
            if (-not (Test-LiquidTruthy -Value $InputObject) -or [string]::IsNullOrEmpty((ConvertTo-LiquidOutputString -Value $InputObject))) {
                return $Arguments[0]
            }

            return $InputObject
        }
        'escape' { return [System.Net.WebUtility]::HtmlEncode((ConvertTo-LiquidOutputString -Value $InputObject)) }
        'escape_once' { return [System.Net.WebUtility]::HtmlEncode([System.Net.WebUtility]::HtmlDecode((ConvertTo-LiquidOutputString -Value $InputObject))) }
        'size' {
            if ($InputObject -is [string]) { return $InputObject.Length }
            if ($InputObject -is [System.Collections.ICollection]) { return $InputObject.Count }
            if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject.Count }
            return (ConvertTo-LiquidOutputString -Value $InputObject).Length
        }
        'plus' {
            $left = ConvertTo-LiquidNumericValue -Value $InputObject
            $right = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            return $left + $right
        }
        'minus' {
            $left = ConvertTo-LiquidNumericValue -Value $InputObject
            $right = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            return $left - $right
        }
        'times' {
            $left = ConvertTo-LiquidNumericValue -Value $InputObject
            $right = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            return $left * $right
        }
        'divided_by' {
            $left = ConvertTo-LiquidNumericValue -Value $InputObject
            $right = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            if ($right -eq 0) { throw 'Liquid divided_by by zero is not allowed.' }
            return $left / $right
        }
        'modulo' {
            $left = ConvertTo-LiquidNumericValue -Value $InputObject
            $right = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            if ($right -eq 0) { throw 'Liquid modulo by zero is not allowed.' }
            return $left % $right
        }
        'abs' {
            $value = ConvertTo-LiquidNumericValue -Value $InputObject
            return [math]::Abs($value)
        }
        'at_least' {
            $value = ConvertTo-LiquidNumericValue -Value $InputObject
            $min = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            if ($value -lt $min) {
                return $min
            }
            return $value
        }
        'at_most' {
            $value = ConvertTo-LiquidNumericValue -Value $InputObject
            $max = ConvertTo-LiquidNumericValue -Value $Arguments[0]
            if ($value -gt $max) {
                return $max
            }
            return $value
        }
        'floor' {
            $value = ConvertTo-LiquidNumericValue -Value $InputObject
            return [math]::Floor($value)
        }
        'round' {
            $value = ConvertTo-LiquidNumericValue -Value $InputObject
            $precision = 0
            if ($Arguments.Count -gt 0) {
                $precision = [int](ConvertTo-LiquidNumericValue -Value $Arguments[0])
            }
            return [math]::Round($value, $precision, [System.MidpointRounding]::AwayFromZero)
        }
        'capitalize' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            return [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($text.ToLowerInvariant())
        }
        'concat' {
            if ($Arguments.Count -ne 1) { throw "The 'concat' filter requires 1 argument: array to concatenate" }
            if ($InputObject -isnot [System.Collections.IEnumerable] -or $InputObject -is [string]) {
                throw "The 'concat' filter requires an array input."
            }

            if ($Arguments[0] -isnot [System.Collections.IEnumerable] -or $Arguments[0] -is [string]) {
                throw "The 'concat' filter requires an array argument."
            }

            $result = New-Object System.Collections.ArrayList
            [void]$result.AddRange(@($InputObject))
            [void]$result.AddRange(@($Arguments[0]))
            return ,@($result.ToArray())
        }
        'newline_to_br' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            return $text.Replace('\n', '<br>').Replace('\r', '<br>')
        }
        'remove' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $substring = ConvertTo-LiquidOutputString -Value $Arguments[0]
            return $text.Replace($substring, '')
        }
        'remove_first' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $substring = ConvertTo-LiquidOutputString -Value $Arguments[0]
            $index = $text.IndexOf($substring)
            if ($index -ge 0) {
                return $text.Remove($index, $substring.Length)
            }
            return $text
        }
        'remove_last' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $substring = ConvertTo-LiquidOutputString -Value $Arguments[0]
            $index = $text.LastIndexOf($substring)
            if ($index -ge 0) {
                return $text.Remove($index, $substring.Length)
            }
            return $text
        }
        'replace' {
            if ($Arguments.Count -lt 2) { throw "The 'replace' filter requires 2 arguments: old value and new value" }
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $oldValue = ConvertTo-LiquidOutputString -Value $Arguments[0]
            $newValue = ConvertTo-LiquidOutputString -Value $Arguments[1]
            return $text.Replace($oldValue, $newValue)
        }
        'replace_first' {
            if ($Arguments.Count -lt 2) { throw "The 'replace_first' filter requires 2 arguments: old value and new value" }
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $oldValue = ConvertTo-LiquidOutputString -Value $Arguments[0]
            $newValue = ConvertTo-LiquidOutputString -Value $Arguments[1]
            $index = $text.IndexOf($oldValue)
            if ($index -ge 0) {
                return $text.Remove($index, $oldValue.Length).Insert($index, $newValue)
            }
            return $text
        }
        'replace_last' {
            if ($Arguments.Count -lt 2) { throw "The 'replace_last' filter requires 2 arguments: old value and new value" }
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $oldValue = ConvertTo-LiquidOutputString -Value $Arguments[0]
            $newValue = ConvertTo-LiquidOutputString -Value $Arguments[1]
            $index = $text.LastIndexOf($oldValue)
            if ($index -ge 0) {
                return $text.Remove($index, $oldValue.Length).Insert($index, $newValue)
            }
            return $text
        }
        'reverse' {
            if ($InputObject -is [string]) {
                $chars = $InputObject.ToCharArray()
                [array]::Reverse($chars)
                return New-Object string ($chars, 0, $chars.Length)
            }
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                $array = @($InputObject)
                [array]::Reverse($array)
                return ,$array
            }
            return $InputObject
        }
        'slice' {
            if ($Arguments.Count -lt 1) { throw "The 'slice' filter requires at least 1 argument: start index" }

            $start = [int](ConvertTo-LiquidNumericValue -Value $Arguments[0])
            $length = 1
            if ($Arguments.Count -gt 1) {
                $length = [int](ConvertTo-LiquidNumericValue -Value $Arguments[1])
            }

            if ($InputObject -is [string]) {
                $text = ConvertTo-LiquidOutputString -Value $InputObject
                $startIndex = if ($start -lt 0) { $text.Length + $start } else { $start }
                if ($startIndex -lt 0 -or $startIndex -ge $text.Length -or $length -le 0) {
                    return ''
                }

                $safeLength = [Math]::Min($length, $text.Length - $startIndex)
                return $text.Substring($startIndex, $safeLength)
            }

            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                $items = @($InputObject)
                $startIndex = if ($start -lt 0) { $items.Count + $start } else { $start }
                if ($startIndex -lt 0 -or $startIndex -ge $items.Count -or $length -le 0) {
                    return ,@()
                }

                $safeLength = [Math]::Min($length, $items.Count - $startIndex)
                return ,@($items[$startIndex..($startIndex + $safeLength - 1)])
            }

            return $InputObject
        }
        'strip_newlines' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            return $text.Replace('\n', '').Replace('\r', '')
        }
        'strip_html' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            return ([System.Text.RegularExpressions.Regex]::Replace($text, '<[^>]+>', '')).Trim()
        }
        'url_encode' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            return [System.Uri]::EscapeDataString($text)
        }
        'url_decode' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            return [System.Uri]::UnescapeDataString($text.Replace('+', '%20'))
        }
        'truncate' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $length = 50
            if ($Arguments.Count -gt 0) {
                $length = [int](ConvertTo-LiquidNumericValue -Value $Arguments[0])
            }

            $suffix = '...'
            if ($Arguments.Count -gt 1) {
                $suffix = ConvertTo-LiquidOutputString -Value $Arguments[1]
            }

            if ($length -le 0) {
                return ''
            }

            if ($text.Length -le $length) {
                return $text
            }

            if ($suffix.Length -ge $length) {
                return $suffix.Substring(0, $length)
            }

            $truncatedLength = $length - $suffix.Length
            if ($truncatedLength -lt 0) {
                $truncatedLength = 0
            }

            return $text.Substring(0, $truncatedLength) + $suffix
        }
        'truncatewords' {
            $text = ConvertTo-LiquidOutputString -Value $InputObject
            $wordCount = [int](ConvertTo-LiquidNumericValue -Value $Arguments[0])
            $suffix = '...'
            if ($Arguments.Count -gt 1) {
                $suffix = ConvertTo-LiquidOutputString -Value $Arguments[1]
            }
            $words = $text -split '\s+'
            if ($words.Count -le $wordCount) {
                return $text
            }
            $truncatedWords = $words[0..($wordCount - 1)]
            return ($truncatedWords -join ' ') + $suffix
        }
        'sum' {
            $total = 0
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                foreach ($item in $InputObject) {
                    try {
                        $total += ConvertTo-LiquidNumericValue -Value $item
                    } catch {
                        # Skip non-numeric items
                    }
                }
            }
            return $total
        }
        'date' {
            $dateValue = $null
            $inputString = ConvertTo-LiquidOutputString -Value $InputObject
            if ($inputString -ieq 'now' -or $inputString -ieq 'today') {
                $dateValue = [datetime]::Now
            } else {
                $dateValue = [datetime]$InputObject
            }
            $formatString = ConvertTo-LiquidOutputString -Value $Arguments[0]
            return $dateValue.ToString($formatString)
        }
        'split' { return (ConvertTo-LiquidOutputString -Value $InputObject).Split([string]$Arguments[0], [System.StringSplitOptions]::None) }
        'join' {
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                return (($InputObject | ForEach-Object { ConvertTo-LiquidOutputString -Value $_ }) -join [string]$Arguments[0])
            }

            return ConvertTo-LiquidOutputString -Value $InputObject
        }
        'first' {
            if ($InputObject -is [System.Collections.IList]) { return if ($InputObject.Count -gt 0) { $InputObject[0] } else { $null } }
            return $null
        }
        'last' {
            if ($InputObject -is [System.Collections.IList]) { return if ($InputObject.Count -gt 0) { $InputObject[$InputObject.Count - 1] } else { $null } }
            return $null
        }
        'relative_url' {
            if ($dialect -ne 'JekyllLiquid') {
                throw "Liquid filter '$Name' is not supported in the '$dialect' dialect."
            }

            $site = Resolve-LiquidVariable -Runtime $Runtime -Path 'site'
            $baseUrl = if ($site) { Get-LiquidRuntimeValue -Value $site -MemberName 'baseurl' } else { $null }
            $path = ConvertTo-LiquidOutputString -Value $InputObject

            if ([string]::IsNullOrWhiteSpace($baseUrl)) {
                return $path
            }

            return ($baseUrl.TrimEnd('/') + '/' + $path.TrimStart('/'))
        }
        'absolute_url' {
            if ($dialect -ne 'JekyllLiquid') {
                throw "Liquid filter '$Name' is not supported in the '$dialect' dialect."
            }

            $site = Resolve-LiquidVariable -Runtime $Runtime -Path 'site'
            $siteUrl = if ($site) { Get-LiquidRuntimeValue -Value $site -MemberName 'url' } else { $null }
            $relativePath = Invoke-LiquidFilter -Name 'relative_url' -InputObject $InputObject -Arguments @() -Runtime $Runtime

            if ([string]::IsNullOrWhiteSpace($siteUrl)) {
                return $relativePath
            }

            return ($siteUrl.TrimEnd('/') + '/' + ([string]$relativePath).TrimStart('/'))
        }
        'xml_escape' {
            if ($dialect -ne 'JekyllLiquid') {
                throw "Liquid filter '$Name' is not supported in the '$dialect' dialect."
            }

            $value = ConvertTo-LiquidOutputString -Value $InputObject
            $escaped = [System.Security.SecurityElement]::Escape($value)
            return $escaped.Replace("'", '&apos;')
        }
        'date_to_xmlschema' {
            if ($dialect -ne 'JekyllLiquid') {
                throw "Liquid filter '$Name' is not supported in the '$dialect' dialect."
            }

            $dateValue = if ($InputObject -is [datetime]) { $InputObject } else { [datetime]$InputObject }
            return $dateValue.ToString('yyyy-MM-ddTHH:mm:ssK')
        }
        'date_to_rfc822' {
            if ($dialect -ne 'JekyllLiquid') {
                throw "Liquid filter '$Name' is not supported in the '$dialect' dialect."
            }

            $dateValue = if ($InputObject -is [datetime]) { $InputObject } else { [datetime]$InputObject }
            return $dateValue.ToString('ddd, dd MMM yyyy HH:mm:ss K', [System.Globalization.CultureInfo]::InvariantCulture)
        }
        'jsonify' {
            if ($dialect -ne 'JekyllLiquid') {
                throw "Liquid filter '$Name' is not supported in the '$dialect' dialect."
            }

            return (ConvertTo-Json -InputObject $InputObject -Depth 20 -Compress)
        }
        'sort' {
            if ($InputObject -isnot [System.Collections.IEnumerable] -or $InputObject -is [string]) {
                return $InputObject
            }

            $propertyName = if ($Arguments.Count -gt 0) { ConvertTo-LiquidOutputString -Value $Arguments[0] } else { $null }
            $sortedItems = @(
                @($InputObject) |
                    Sort-Object -Stable -Property @{
                        Expression = { Resolve-LiquidSortValue -Value $_ -PropertyName $propertyName }
                    }
            )
            return ,$sortedItems
        }
        'sort_natural' {
            if ($InputObject -isnot [System.Collections.IEnumerable] -or $InputObject -is [string]) {
                return $InputObject
            }

            $propertyName = if ($Arguments.Count -gt 0) { ConvertTo-LiquidOutputString -Value $Arguments[0] } else { $null }
            $sortedItems = @(
                @($InputObject) |
                    Sort-Object -Stable -Property @{
                        Expression = { ConvertTo-LiquidNaturalSortKey -Value (Resolve-LiquidSortValue -Value $_ -PropertyName $propertyName) }
                    }
            )
            return ,$sortedItems
        }
        'uniq' {
            if ($InputObject -isnot [System.Collections.IEnumerable] -or $InputObject -is [string]) {
                return $InputObject
            }

            $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
            $uniqueItems = New-Object System.Collections.ArrayList
            foreach ($item in @($InputObject)) {
                $key = ConvertTo-Json -InputObject $item -Depth 20 -Compress
                if ($seen.Add($key)) {
                    [void]$uniqueItems.Add($item)
                }
            }

            return ,@($uniqueItems.ToArray())
        }
        # TODO: Add Liquid filter support for map.
        # TODO: Add Liquid filter support for where.
        default { throw "Liquid filter '$Name' is not supported." }
    }
}

function Resolve-LiquidExpression {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # An expression is a base value followed by an optional chain of filters.
    $segments = Split-LiquidDelimitedString -InputText $Expression -Delimiter '|'
    $value = ConvertTo-LiquidLiteralValue -Expression $segments[0] -Runtime $Runtime

    foreach ($segment in $segments | Select-Object -Skip 1) {
        $trimmedSegment = $segment.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedSegment)) {
            continue
        }

        $filterParts = Split-LiquidDelimitedString -InputText $trimmedSegment -Delimiter ':'
        $filterName = $filterParts[0].Trim()
        $arguments = @()

        if ($filterParts.Count -gt 1) {
            $argumentExpressions = Split-LiquidDelimitedString -InputText ([string]$filterParts[1]) -Delimiter ','
            $argumentList = New-Object System.Collections.ArrayList
            foreach ($argExpr in $argumentExpressions) {
                $resolvedArg = Resolve-LiquidExpression -Expression $argExpr.Trim() -Runtime $Runtime
                [void]$argumentList.Add($resolvedArg)
            }

            $arguments = @($argumentList.ToArray())
        }

        $value = Invoke-LiquidFilter -Name $filterName -InputObject $value -Arguments $arguments -Runtime $Runtime
    }

    return $value
}

function Split-LiquidConditionToken {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Condition
    )

    # Keep quoted strings intact while splitting a condition into comparison tokens.
    $regexMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $Condition,
        '(?:"[^"]*"|''[^'']*''|\S+)'
    )

    return ,@($regexMatches | ForEach-Object { $_.Value })
}

function Invoke-LiquidComparison {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Tokens,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # A bare value in Liquid is interpreted by its truthiness; otherwise compare left/operator/right.
    if ($Tokens.Count -eq 1) {
        return Test-LiquidTruthy -Value (ConvertTo-LiquidLiteralValue -Expression $Tokens[0] -Runtime $Runtime)
    }

    if ($Tokens.Count -lt 3) {
        throw "Liquid condition is invalid: '$($Tokens -join ' ')'."
    }

    $left = ConvertTo-LiquidLiteralValue -Expression $Tokens[0] -Runtime $Runtime
    $operator = $Tokens[1]
    $right = ConvertTo-LiquidLiteralValue -Expression $Tokens[2] -Runtime $Runtime

    switch ($operator) {
        '==' { return ($left -eq $right) }
        '!=' { return ($left -ne $right) }
        '>' { return ($left -gt $right) }
        '<' { return ($left -lt $right) }
        '>=' { return ($left -ge $right) }
        '<=' { return ($left -le $right) }
        'contains' {
            if ($left -is [string]) {
                return $left.Contains([string]$right)
            }

            if ($left -is [System.Collections.IEnumerable] -and $left -isnot [string]) {
                foreach ($item in $left) {
                    if ($item -eq $right) {
                        return $true
                    }
                }
            }

            return $false
        }
        default {
            throw "Liquid operator '$operator' is not supported."
        }
    }
}

function Invoke-LiquidConditionToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Tokens,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Evaluate logical operators right-to-left by splitting on the leftmost logical operator first.
    for ($index = 0; $index -lt $Tokens.Count; $index++) {
        switch ($Tokens[$index]) {
            'and' {
                $leftTokens = if ($index -gt 0) { $Tokens[0..($index - 1)] } else { @() }
                $rightTokens = if ($index + 1 -lt $Tokens.Count) { $Tokens[($index + 1)..($Tokens.Count - 1)] } else { @() }
                return ((Invoke-LiquidConditionToken -Tokens $leftTokens -Runtime $Runtime) -and (Invoke-LiquidConditionToken -Tokens $rightTokens -Runtime $Runtime))
            }
            'or' {
                $leftTokens = if ($index -gt 0) { $Tokens[0..($index - 1)] } else { @() }
                $rightTokens = if ($index + 1 -lt $Tokens.Count) { $Tokens[($index + 1)..($Tokens.Count - 1)] } else { @() }
                return ((Invoke-LiquidConditionToken -Tokens $leftTokens -Runtime $Runtime) -or (Invoke-LiquidConditionToken -Tokens $rightTokens -Runtime $Runtime))
            }
        }
    }

    return Invoke-LiquidComparison -Tokens $Tokens -Runtime $Runtime
}

function Invoke-LiquidCondition {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Condition,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    if ($Condition.Contains('(') -or $Condition.Contains(')')) {
        throw 'Liquid conditions do not support parentheses.'
    }

    # Condition evaluation is split into tokenization and recursive logical/comparison evaluation.
    $tokens = Split-LiquidConditionToken -Condition $Condition
    return Invoke-LiquidConditionToken -Tokens $tokens -Runtime $Runtime
}

function newLiquidRuntime {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [string]$IncludeRoot,

        [string]$CurrentFilePath,

        [string]$RelativeIncludeRoot,

        [string[]]$IncludeStack = @(),

        [hashtable]$Registry
    )

    $scopes = New-Object System.Collections.ArrayList
    [void]$scopes.Add((ConvertToLiquidSafeValue -Value $Context -Registry $Registry))

    return @{
        Scopes              = $scopes
        Dialect             = $Dialect
        IncludeRoot         = $IncludeRoot
        CurrentFilePath     = $CurrentFilePath
        RelativeIncludeRoot = $RelativeIncludeRoot
        IncludeStack        = @($IncludeStack)
        Registry            = if ($null -ne $Registry) { $Registry } else { newLiquidExtensionRegistry }
        Counters            = @{}
        CycleStates         = @{}
        LoopDepth           = 0
        ControlFlow         = $null
    }
}

function Add-LiquidScope {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime,

        [Parameter(Mandatory = $true)]
        [hashtable]$Scope
    )

    # New scopes are pushed to the front so lookups see the most local variables first.
    $Runtime.Scopes.Insert(0, (ConvertToLiquidSafeValue -Value $Scope -Registry $Runtime.Registry))
}

function removeLiquidScope {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Keep the root context scope in place even when temporary scopes are removed.
    if ($Runtime.Scopes.Count -gt 1) {
        $Runtime.Scopes.RemoveAt(0)
    }
}

function Resolve-LiquidIncludePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IncludeTarget,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Includes resolve from the configured include root and stay inside that tree.
    if ([string]::IsNullOrWhiteSpace($Runtime.IncludeRoot)) {
        throw "Liquid include root is not configured."
    }

    $normalizedTarget = $IncludeTarget.Replace('/', [System.IO.Path]::DirectorySeparatorChar).Replace('\', [System.IO.Path]::DirectorySeparatorChar)
    $includePath = Join-Path -Path $Runtime.IncludeRoot -ChildPath $normalizedTarget
    $resolvedIncludePath = [System.IO.Path]::GetFullPath($includePath)
    $resolvedIncludeRoot = [System.IO.Path]::GetFullPath($Runtime.IncludeRoot)

    if (-not $resolvedIncludePath.StartsWith($resolvedIncludeRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -and
        ($resolvedIncludePath -ne $resolvedIncludeRoot)) {
        throw "Liquid include '$IncludeTarget' resolves outside the include root."
    }

    if (-not (Test-Path -LiteralPath $resolvedIncludePath -PathType Leaf)) {
        throw "Could not locate the included file '$IncludeTarget' in '$resolvedIncludeRoot'."
    }

    return $resolvedIncludePath
}

function Resolve-LiquidRelativeIncludePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IncludeTarget,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # include_relative resolves from the current template file, but hosts still choose the allowed root.
    if ([string]::IsNullOrWhiteSpace($Runtime.CurrentFilePath)) {
        throw "Liquid include_relative requires the current template file path to be provided by the host."
    }

    if ([string]::IsNullOrWhiteSpace($Runtime.RelativeIncludeRoot)) {
        throw "Liquid include_relative is not allowed because no relative include root is configured for the current template."
    }

    $normalizedTarget = $IncludeTarget.Replace('/', [System.IO.Path]::DirectorySeparatorChar).Replace('\', [System.IO.Path]::DirectorySeparatorChar)
    $currentDirectory = Split-Path -Path $Runtime.CurrentFilePath -Parent
    $includePath = Join-Path -Path $currentDirectory -ChildPath $normalizedTarget
    $resolvedIncludePath = [System.IO.Path]::GetFullPath($includePath)
    $resolvedRelativeRoot = [System.IO.Path]::GetFullPath($Runtime.RelativeIncludeRoot)

    if (-not $resolvedIncludePath.StartsWith($resolvedRelativeRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -and
        ($resolvedIncludePath -ne $resolvedRelativeRoot)) {
        throw "Liquid include_relative '$IncludeTarget' resolves outside the allowed relative include root."
    }

    if (-not (Test-Path -LiteralPath $resolvedIncludePath -PathType Leaf)) {
        throw "Could not locate the include_relative file '$IncludeTarget' beneath '$resolvedRelativeRoot'."
    }

    return $resolvedIncludePath
}

function Invoke-LiquidInclude {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $Node,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Include is deprecated in standard Liquid, but preserved for JekyllLiquid compatibility.
    if ($Runtime.Dialect -ne 'JekyllLiquid') {
        Write-Warning "Liquid tag 'include' is deprecated in the '$($Runtime.Dialect)' dialect and will be ignored."
        return ''
    }

    $includeTarget = Resolve-LiquidExpression -Expression $Node.TargetExpression -Runtime $Runtime
    $includeName = ConvertTo-LiquidOutputString -Value $includeTarget
    if ([string]::IsNullOrWhiteSpace($includeName)) {
        # Jekyll commonly uses bare include filenames without quotes, so fall back to the raw token when it is not a resolved variable.
        $includeName = $Node.TargetExpression.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($includeName)) {
        throw "Liquid include target is empty."
    }

    $includePath = Resolve-LiquidIncludePath -IncludeTarget $includeName -Runtime $Runtime
    if ($Runtime.IncludeStack -contains $includePath) {
        throw "Liquid include '$includeName' is recursively including itself."
    }

    $includeVariables = @{}
    foreach ($parameter in $Node.Parameters) {
        $includeVariables[$parameter.Name] = Resolve-LiquidExpression -Expression $parameter.Expression -Runtime $Runtime
    }

    $includeVariables['file'] = $includeName
    $includeContext = @{}
    foreach ($scope in $Runtime.Scopes) {
        if ($scope -is [System.Collections.IDictionary]) {
            foreach ($key in $scope.Keys) {
                if (-not $includeContext.ContainsKey($key)) {
                    $includeContext[$key] = $scope[$key]
                }
            }
        }
    }

    $includeContext['include'] = $includeVariables
    $template = Get-Content -LiteralPath $includePath -Raw
    return Invoke-LiquidTemplate -Template $template -Context $includeContext -Dialect $Runtime.Dialect -IncludeRoot $Runtime.IncludeRoot -CurrentFilePath $includePath -RelativeIncludeRoot $Runtime.RelativeIncludeRoot -IncludeStack ($Runtime.IncludeStack + $includePath) -Registry $Runtime.Registry
}

function Invoke-LiquidRelativeInclude {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        $Node,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    if ($Runtime.Dialect -ne 'JekyllLiquid') {
        throw "Liquid tag 'include_relative' is not supported in the '$($Runtime.Dialect)' dialect."
    }

    $includeTarget = Resolve-LiquidExpression -Expression $Node.TargetExpression -Runtime $Runtime
    $includeName = ConvertTo-LiquidOutputString -Value $includeTarget
    if ([string]::IsNullOrWhiteSpace($includeName)) {
        $includeName = $Node.TargetExpression.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($includeName)) {
        throw "Liquid include_relative target is empty."
    }

    $includePath = Resolve-LiquidRelativeIncludePath -IncludeTarget $includeName -Runtime $Runtime
    if ($Runtime.IncludeStack -contains $includePath) {
        throw "Liquid include_relative '$includeName' is recursively including itself."
    }

    $includeContext = @{}
    foreach ($scope in $Runtime.Scopes) {
        if ($scope -is [System.Collections.IDictionary]) {
            foreach ($key in $scope.Keys) {
                if (-not $includeContext.ContainsKey($key)) {
                    $includeContext[$key] = $scope[$key]
                }
            }
        }
    }

    $template = Get-Content -LiteralPath $includePath -Raw
    return Invoke-LiquidTemplate -Template $template -Context $includeContext -Dialect $Runtime.Dialect -IncludeRoot $Runtime.IncludeRoot -CurrentFilePath $includePath -RelativeIncludeRoot $Runtime.RelativeIncludeRoot -IncludeStack ($Runtime.IncludeStack + $includePath) -Registry $Runtime.Registry
}

function ConvertTo-LiquidEnumerable {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        $Value
    )

    # For loops render lists naturally and treat scalars as one-item sequences.
    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @($Value)
    }

    if ($Value -is [System.Collections.IDictionary]) {
        return @($Value.GetEnumerator())
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value)
    }

    return @($Value)
}

function ConvertFrom-LiquidNode {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Nodes,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    $builder = New-Object System.Text.StringBuilder

    foreach ($node in $Nodes) {
        switch ($node.Type) {
            'Text' { [void]$builder.Append($node.Value) }
            'Output' {
                $value = Resolve-LiquidExpression -Expression $node.Expression -Runtime $Runtime
                [void]$builder.Append((ConvertTo-LiquidOutputString -Value $value))
            }
            'Assign' {
                $value = Resolve-LiquidExpression -Expression $node.Expression -Runtime $Runtime
                $Runtime.Scopes[0][$node.Name] = $value
            }
            'Capture' {
                $capturedValue = ConvertFrom-LiquidNode -Nodes $node.Nodes -Runtime $Runtime
                $Runtime.Scopes[0][$node.Name] = $capturedValue
            }
            'If' {
                $rendered = $false
                foreach ($branch in $node.Branches) {
                    if (Invoke-LiquidCondition -Condition $branch.Condition -Runtime $Runtime) {
                        [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $branch.Nodes -Runtime $Runtime))
                        $rendered = $true
                        break
                    }
                }
                if (-not $rendered -and $node.Else.Count -gt 0) {
                    [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Else -Runtime $Runtime))
                }
            }
            'Unless' {
                if (-not (Invoke-LiquidCondition -Condition $node.Condition -Runtime $Runtime)) {
                    [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Nodes -Runtime $Runtime))
                } elseif ($node.Else.Count -gt 0) {
                    [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Else -Runtime $Runtime))
                }
            }
            'For' {
                $items = @(ConvertTo-LiquidEnumerable -Value (Resolve-LiquidExpression -Expression $node.CollectionExpression -Runtime $Runtime))
                if ($items.Count -eq 0) {
                    if ($node.Else.Count -gt 0) { [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Else -Runtime $Runtime)) }
                    continue
                }
                # TODO: Add Liquid tag support for forloop.
                $outerForLoop = Resolve-LiquidVariable -Runtime $Runtime -Path 'forloop'
                $Runtime.LoopDepth++
                try {
                    for ($index = 0; $index -lt $items.Count; $index++) {
                        $loopScope = @{
                            $node.VariableName = $items[$index]
                            forloop            = @{
                                name       = $node.VariableName
                                length     = $items.Count
                                index      = $index + 1
                                index0     = $index
                                rindex     = $items.Count - $index
                                rindex0    = $items.Count - $index - 1
                                first      = ($index -eq 0)
                                last       = ($index -eq ($items.Count - 1))
                                parentloop = $outerForLoop
                            }
                        }
                        Add-LiquidScope -Runtime $Runtime -Scope $loopScope
                        try { [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Nodes -Runtime $Runtime)) } finally { removeLiquidScope -Runtime $Runtime }
                        if ($Runtime.ControlFlow -eq 'Continue') { $Runtime.ControlFlow = $null; continue }
                        if ($Runtime.ControlFlow -eq 'Break') { $Runtime.ControlFlow = $null; break }
                    }
                } finally { $Runtime.LoopDepth-- }
            }
            'Case' {
                $caseValue = Resolve-LiquidExpression -Expression $node.Expression -Runtime $Runtime
                $matched = $false
                foreach ($when in $node.Whens) {
                    foreach ($valueExpression in $when.Values) {
                        $candidate = Resolve-LiquidExpression -Expression $valueExpression -Runtime $Runtime
                        if ($caseValue -eq $candidate) {
                            [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $when.Nodes -Runtime $Runtime))
                            $matched = $true
                            break
                        }
                    }
                    if ($matched) { break }
                }
                if (-not $matched -and $node.Else.Count -gt 0) { [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Else -Runtime $Runtime)) }
            }
            'Cycle' {
                $groupKey = if ([string]::IsNullOrWhiteSpace($node.GroupExpression)) { ($node.ValueExpressions -join '|') } else { ConvertTo-LiquidOutputString -Value (Resolve-LiquidExpression -Expression $node.GroupExpression -Runtime $Runtime) }
                if (-not $Runtime.CycleStates.ContainsKey($groupKey)) { $Runtime.CycleStates[$groupKey] = 0 }
                $position = [int]$Runtime.CycleStates[$groupKey]
                $expressionIndex = $position % $node.ValueExpressions.Count
                $cycleValue = Resolve-LiquidExpression -Expression $node.ValueExpressions[$expressionIndex] -Runtime $Runtime
                [void]$builder.Append((ConvertTo-LiquidOutputString -Value $cycleValue))
                $Runtime.CycleStates[$groupKey] = $position + 1
            }
            'Increment' {
                if (-not $Runtime.Counters.ContainsKey($node.Name)) { $Runtime.Counters[$node.Name] = 0 }
                $currentValue = [int]$Runtime.Counters[$node.Name]
                [void]$builder.Append([string]$currentValue)
                $Runtime.Counters[$node.Name] = $currentValue + 1
            }
            'Decrement' {
                if (-not $Runtime.Counters.ContainsKey($node.Name)) { $Runtime.Counters[$node.Name] = 0 }
                $Runtime.Counters[$node.Name] = [int]$Runtime.Counters[$node.Name] - 1
                [void]$builder.Append([string]$Runtime.Counters[$node.Name])
            }
            'Break' {
                if ($Runtime.LoopDepth -lt 1) { throw 'Liquid break tag can only be used inside for or tablerow loops.' }
                $Runtime.ControlFlow = 'Break'
                return $builder.ToString()
            }
            'Continue' {
                if ($Runtime.LoopDepth -lt 1) { throw 'Liquid continue tag can only be used inside for or tablerow loops.' }
                $Runtime.ControlFlow = 'Continue'
                return $builder.ToString()
            }
            'Tablerow' {
                $items = @(ConvertTo-LiquidEnumerable -Value (Resolve-LiquidExpression -Expression $node.CollectionExpression -Runtime $Runtime))
                if ($items.Count -eq 0) { continue }
                # TODO: Add Liquid tag support for tablerowloop.
                $outerTablerowLoop = Resolve-LiquidVariable -Runtime $Runtime -Path 'tablerowloop'
                $Runtime.LoopDepth++
                try {
                    for ($index = 0; $index -lt $items.Count; $index++) {
                        $columnIndex = ($index % $node.Columns) + 1
                        $rowIndex = [math]::Floor($index / $node.Columns) + 1
                        if ($columnIndex -eq 1) { [void]$builder.Append('<tr class=""row' + $rowIndex + '"">') }
                        [void]$builder.Append('<td class=""col' + $columnIndex + '"">')
                        $loopScope = @{
                            $node.VariableName = $items[$index]
                            tablerowloop       = @{
                                col        = $columnIndex
                                col0       = $columnIndex - 1
                                row        = $rowIndex
                                row0       = $rowIndex - 1
                                index      = $index + 1
                                index0     = $index
                                first      = ($index -eq 0)
                                last       = ($index -eq ($items.Count - 1))
                                length     = $items.Count
                                cols       = $node.Columns
                                parentloop = $outerTablerowLoop
                            }
                        }
                        Add-LiquidScope -Runtime $Runtime -Scope $loopScope
                        try { [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Nodes -Runtime $Runtime)) } finally { removeLiquidScope -Runtime $Runtime }
                        [void]$builder.Append('</td>')
                        $shouldCloseRow = (($columnIndex -eq $node.Columns) -or ($index -eq ($items.Count - 1)))
                        if ($Runtime.ControlFlow -eq 'Continue') { $Runtime.ControlFlow = $null }
                        if ($shouldCloseRow) { [void]$builder.Append('</tr>') }
                        if ($Runtime.ControlFlow -eq 'Break') {
                            $Runtime.ControlFlow = $null
                            if (-not $shouldCloseRow) { [void]$builder.Append('</tr>') }
                            break
                        }
                    }
                } finally { $Runtime.LoopDepth-- }
            }
            'Include' { [void]$builder.Append((Invoke-LiquidInclude -Node $node -Runtime $Runtime)) }
            'IncludeRelative' { [void]$builder.Append((Invoke-LiquidRelativeInclude -Node $node -Runtime $Runtime)) }
            'CustomTag' {
                $customTag = Get-LiquidCustomTag -Name $node.Name -Runtime $Runtime
                if ($null -eq $customTag) { throw "Liquid tag '$($node.Name)' is not supported in the '$($Runtime.Dialect)' dialect." }
                $invocation = newLiquidExtensionInvocation -Runtime $Runtime
                $invocation['Name'] = $node.Name
                $invocation['Markup'] = $node.Markup
                [void]$builder.Append((ConvertTo-LiquidOutputString -Value (& $customTag $invocation)))
            }
            default { throw "Liquid node type '$($node.Type)' is not supported." }
        }
        if ($Runtime.ControlFlow) {
            return $builder.ToString()
        }
    }

    return $builder.ToString()
}

<#
.SYNOPSIS
Parses a Liquid template into an abstract syntax tree.
.DESCRIPTION
Parses a Liquid template and returns a documented AST object that can be used by
tooling, diagnostics, or host applications that need to inspect Liquid syntax
without rendering it immediately.

The returned AST root contains the selected dialect and the parsed node tree.
Optionally, the original token stream can also be included for debugging or tooling.
.PARAMETER Template
The Liquid template source to parse.
.PARAMETER Dialect
The Liquid dialect to validate against.
.PARAMETER Registry
The extension registry used to recognize host-provided tags and filters while parsing.
.PARAMETER IncludeTokens
Includes the tokenizer output alongside the AST node tree.
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

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [hashtable]$Registry = (newLiquidExtensionRegistry),

        [switch]$IncludeTokens
    )

    AssertLiquidDialect -Dialect $Dialect

    # Tokenize first so the AST API can optionally return both the raw token stream and the nested node tree.
    $tokens = ConvertTo-LiquidToken -Template $Template
    $index = 0
    $nodes = parseLiquidNode -Tokens $tokens -Index ([ref]$index) -Registry $Registry

    # Expose a stable root object so hosts can rely on one entry shape instead of a raw node array.
    $ast = [pscustomobject]@{
        PSTypeName = 'PowerLiquid.Ast'
        Dialect    = $Dialect
        Nodes      = @($nodes)
    }

    if ($IncludeTokens) {
        Add-Member -InputObject $ast -MemberType NoteProperty -Name Tokens -Value @($tokens)
    }

    return $ast
}

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

        [ValidateSet('Liquid', 'JekyllLiquid')]
        [string]$Dialect = 'Liquid',

        [string]$IncludeRoot,

        [string]$CurrentFilePath,

        [string]$RelativeIncludeRoot,

        [string[]]$IncludeStack = @(),

        [hashtable]$Registry = (newLiquidExtensionRegistry)
    )

    AssertLiquidDialect -Dialect $Dialect

    $runtime = newLiquidRuntime -Context $Context -Dialect $Dialect -IncludeRoot $IncludeRoot -CurrentFilePath $CurrentFilePath -RelativeIncludeRoot $RelativeIncludeRoot -IncludeStack $IncludeStack -Registry $Registry
    $ast = ConvertTo-LiquidAst -Template $Template -Dialect $Dialect -Registry $Registry
    return ConvertFrom-LiquidNode -Nodes $ast.Nodes -Runtime $runtime
}



