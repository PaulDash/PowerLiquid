---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
---

# ConvertTo-LiquidAst

## SYNOPSIS
Parses a Liquid template into an Abstract Syntax Tree (AST).

## SYNTAX

```
ConvertTo-LiquidAst [-Template] <String> [[-Dialect] <String>] [[-Registry] <Hashtable>] [-IncludeTokens] [<CommonParameters>]
```

## DESCRIPTION
Tokenizes and parses a Liquid template into a structured AST object for analysis or tooling.
This is the primary PowerLiquid entry point for parse-only inspection of Liquid syntax.
Tokens and AST nodes preserve line, column, and character-index ranges for diagnostics.
Supports multiple dialects and extension registries.

## EXAMPLES

### EXAMPLE 1
```
$ast = ConvertTo-LiquidAst -Template '{% if page.title %}{{ page.title }}{% endif %}' -Dialect JekyllLiquid
```

### EXAMPLE 2
```
$ast = ConvertTo-LiquidAst -Template '{{ user.name }}' -IncludeTokens
```

## PARAMETERS

### -Template
The Liquid template source to parse.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Dialect
The Liquid dialect to parse with.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Liquid
Accept pipeline input: False
Accept wildcard characters: False
```

### -Registry
The extension registry containing custom tags and filters.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: (New-LiquidExtensionRegistry)
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeTokens
Include the raw token stream in the AST output.
Tokens also include source locations for diagnostics.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
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

## RELATED LINKS
