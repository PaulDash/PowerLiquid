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
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [string]$Dialect,

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
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [string]$Dialect,

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
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dialect
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
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(Mandatory = $true)]
        [char]$Delimiter
    )

    # Liquid expressions reuse a few delimiter-separated forms, but delimiters inside quotes should be ignored.
    $segments = New-Object System.Collections.ArrayList
    $builder = New-Object System.Text.StringBuilder
    $inSingleQuote = $false
    $inDoubleQuote = $false

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
            default {
                if (($character -eq $Delimiter) -and -not $inSingleQuote -and -not $inDoubleQuote) {
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

function ConvertTo-LiquidToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template
    )

    # Tokenize the template into plain text, output blocks, and tag blocks.
    $tokens = New-Object System.Collections.ArrayList
    $pattern = '\{\{[-]?(.*?)[-]?\}\}|\{%-?(.*?)-?%\}'
    $regexMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $Template,
        $pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    $position = 0
    foreach ($match in $regexMatches) {
        if ($match.Index -gt $position) {
            $text = $Template.Substring($position, $match.Index - $position)
            [void]$tokens.Add([pscustomobject]@{
                Type  = 'Text'
                Raw   = $text
                Value = $text
            })
        }

        if ($match.Value.StartsWith('{{')) {
            [void]$tokens.Add([pscustomobject]@{
                Type  = 'Output'
                Raw   = $match.Value
                Value = $match.Groups[1].Value.Trim()
            })
        } else {
            [void]$tokens.Add([pscustomobject]@{
                Type  = 'Tag'
                Raw   = $match.Value
                Value = $match.Groups[2].Value.Trim()
            })
        }

        $position = $match.Index + $match.Length
    }

    if ($position -lt $Template.Length) {
        $text = $Template.Substring($position)
        [void]$tokens.Add([pscustomobject]@{
            Type  = 'Text'
            Raw   = $text
            Value = $text
        })
    }

    return ,$tokens.ToArray()
}

function getLiquidTagPart {
    [CmdletBinding()]
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

function parseLiquidNode {
    [CmdletBinding()]
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
            [void]$nodes.Add([pscustomobject]@{
                Type  = 'Text'
                Value = $token.Value
            })
            $Index.Value++
            continue
        }

        if ($token.Type -eq 'Output') {
            [void]$nodes.Add([pscustomobject]@{
                Type       = 'Output'
                Expression = $token.Value
            })
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
                # Parse chained if / elsif / else branches into one conditional node.
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
                # Parse for blocks with an optional else branch for empty collections.
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
            'unless' {
                # Unless behaves like an inverted if with an optional else branch.
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
                # Comment blocks are parsed but discarded from the rendered output.
                $Index.Value++
                while ($Index.Value -lt $Tokens.Count) {
                    $commentToken = $Tokens[$Index.Value]
                    if ($commentToken.Type -eq 'Tag') {
                        $commentTag = getLiquidTagPart -Markup $commentToken.Value
                        if ($commentTag.Name -eq 'endcomment') {
                            break
                        }
                    }

                    $Index.Value++
                }

                if ($Index.Value -ge $Tokens.Count) {
                    throw "Liquid comment tag is missing endcomment."
                }

                $Index.Value++
            }
            'raw' {
                # Raw blocks pass their inner source through without further Liquid parsing.
                $Index.Value++
                $rawBuilder = New-Object System.Text.StringBuilder
                while ($Index.Value -lt $Tokens.Count) {
                    $rawToken = $Tokens[$Index.Value]
                    if ($rawToken.Type -eq 'Tag') {
                        $rawTag = getLiquidTagPart -Markup $rawToken.Value
                        if ($rawTag.Name -eq 'endraw') {
                            break
                        }
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
                        Type    = 'CustomTag'
                        Name    = $tagParts.Name
                        Markup  = $tagParts.Markup
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
    return parseLiquidNode -Tokens $tokens -Index ([ref]$index) -Registry $Registry
}

function Get-LiquidRuntimeValue {
    [CmdletBinding()]
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
                Write-Output -NoEnumerate $Value[$key]
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
                    Write-Output -NoEnumerate $Value[0]
                    return
                }

                return $null
            }
            'last' {
                if ($Value.Count -gt 0) {
                    Write-Output -NoEnumerate $Value[$Value.Count - 1]
                    return
                }

                return $null
            }
            default {
                if ($MemberName -match '^\d+$') {
                    $index = [int]$MemberName
                    if ($index -lt $Value.Count) {
                        Write-Output -NoEnumerate $Value[$index]
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
        Write-Output -NoEnumerate $property.Value
        return
    }

    return $null
}

function Resolve-LiquidVariable {
    [CmdletBinding()]
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
                Write-Output -NoEnumerate $value
                return
            }

            return $value
        }
    }

    return $null
}

function ConvertTo-LiquidLiteralValue {
    [CmdletBinding()]
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

function ConvertTo-LiquidOutputString {
    [CmdletBinding()]
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

function Test-LiquidTruthy {
    [CmdletBinding()]
    param(
        $Value
    )

    # Liquid truthiness is intentionally narrower than PowerShell truthiness.
    return (-not ($null -eq $Value -or $Value -eq $false))
}

function getLiquidDialectExtension {
    [CmdletBinding()]
    param(
        [hashtable]$Registry,
        [Parameter(Mandatory = $true)]
        [string]$Dialect
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
        default { throw "Liquid filter '$Name' is not supported." }
    }
}

function Resolve-LiquidExpression {
    [CmdletBinding()]
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
            $argumentExpressions = @(
                Split-LiquidDelimitedString -InputText ([string]$filterParts[1]) -Delimiter ',' |
                    ForEach-Object { [string]$_ }
            )
            $arguments = @(
                $argumentExpressions |
                    ForEach-Object { ConvertTo-LiquidLiteralValue -Expression $_ -Runtime $Runtime }
            )
        }

        $value = Invoke-LiquidFilter -Name $filterName -InputObject $value -Arguments $arguments -Runtime $Runtime
    }

    return $value
}

function Split-LiquidConditionToken {
    [CmdletBinding()]
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
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Tokens,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Evaluate logical operators right-to-left, which matches Liquid's condition parsing rules.
    for ($index = $Tokens.Count - 1; $index -ge 0; $index--) {
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
    param(
        [Parameter(Mandatory = $true)]
        [string]$Condition,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Condition evaluation is split into tokenization and recursive logical/comparison evaluation.
    $tokens = Split-LiquidConditionToken -Condition $Condition
    return Invoke-LiquidConditionToken -Tokens $tokens -Runtime $Runtime
}

function newLiquidRuntime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,

        [Parameter(Mandatory = $true)]
        [string]$Dialect,

        [string]$IncludeRoot,

        [string[]]$IncludeStack = @(),

        [hashtable]$Registry
    )

    # The runtime keeps a scope stack so assign/capture can add temporary variables during rendering.
    $scopes = New-Object System.Collections.ArrayList
    [void]$scopes.Add((ConvertToLiquidSafeValue -Value $Context -Registry $Registry))

    return @{
        Scopes       = $scopes
        Dialect      = $Dialect
        IncludeRoot  = $IncludeRoot
        IncludeStack = @($IncludeStack)
        Registry     = if ($null -ne $Registry) { $Registry } else { newLiquidExtensionRegistry }
    }
}

function Add-LiquidScope {
    [CmdletBinding()]
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

function Invoke-LiquidInclude {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Node,

        [Parameter(Mandatory = $true)]
        [hashtable]$Runtime
    )

    # Include is a Jekyll-style extension point in this module, exposed only through the JekyllLiquid dialect.
    if ($Runtime.Dialect -ne 'JekyllLiquid') {
        throw "Liquid tag 'include' is not supported in the '$($Runtime.Dialect)' dialect."
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
    return Invoke-LiquidTemplate -Template $template -Context $includeContext -Dialect $Runtime.Dialect -IncludeRoot $Runtime.IncludeRoot -IncludeStack ($Runtime.IncludeStack + $includePath) -Registry $Runtime.Registry
}

function ConvertTo-LiquidEnumerable {
    [CmdletBinding()]
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

    # Walk the parsed node tree and turn it back into rendered output text.
    $builder = New-Object System.Text.StringBuilder

    foreach ($node in $Nodes) {
        switch ($node.Type) {
            'Text' {
                [void]$builder.Append($node.Value)
            }
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
                    if ($node.Else.Count -gt 0) {
                        [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Else -Runtime $Runtime))
                    }
                    continue
                }

                $outerForLoop = Resolve-LiquidVariable -Runtime $Runtime -Path 'forloop'
                for ($index = 0; $index -lt $items.Count; $index++) {
                    $loopScope = @{
                        $node.VariableName = $items[$index]
                        forloop            = @{
                            name     = $node.VariableName
                            length   = $items.Count
                            index    = $index + 1
                            index0   = $index
                            rindex   = $items.Count - $index
                            rindex0  = $items.Count - $index - 1
                            first    = ($index -eq 0)
                            last     = ($index -eq ($items.Count - 1))
                            parentloop = $outerForLoop
                        }
                    }

                    Add-LiquidScope -Runtime $Runtime -Scope $loopScope
                    try {
                        [void]$builder.Append((ConvertFrom-LiquidNode -Nodes $node.Nodes -Runtime $Runtime))
                    } finally {
                        removeLiquidScope -Runtime $Runtime
                    }
                }
            }
            'Include' {
                [void]$builder.Append((Invoke-LiquidInclude -Node $node -Runtime $Runtime))
            }
            'CustomTag' {
                $customTag = Get-LiquidCustomTag -Name $node.Name -Runtime $Runtime
                if ($null -eq $customTag) {
                    throw "Liquid tag '$($node.Name)' is not supported in the '$($Runtime.Dialect)' dialect."
                }

                $invocation = newLiquidExtensionInvocation -Runtime $Runtime
                $invocation['Name'] = $node.Name
                $invocation['Markup'] = $node.Markup
                [void]$builder.Append((ConvertTo-LiquidOutputString -Value (& $customTag $invocation)))
            }
            default {
                throw "Liquid node type '$($node.Type)' is not supported."
            }
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

        [string]$Dialect = 'Liquid',

        [string]$IncludeRoot,

        [string[]]$IncludeStack = @(),

        [hashtable]$Registry = (newLiquidExtensionRegistry)
    )

    AssertLiquidDialect -Dialect $Dialect

    $runtime = newLiquidRuntime -Context $Context -Dialect $Dialect -IncludeRoot $IncludeRoot -IncludeStack $IncludeStack -Registry $Registry
    $ast = ConvertTo-LiquidAst -Template $Template -Dialect $Dialect -Registry $Registry
    return ConvertFrom-LiquidNode -Nodes $ast.Nodes -Runtime $runtime
}



