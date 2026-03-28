---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
---

# Invoke-LiquidTemplate

## SYNOPSIS

Renders a Liquid template.

## SYNTAX

```powershell
Invoke-LiquidTemplate [-Template] <String> [-Context] <Hashtable> [[-Dialect] <String>]
 [[-IncludeRoot] <String>] [[-IncludeStack] <String[]>] [[-Registry] <Hashtable>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Parses and renders a Liquid template against a supplied context hashtable.
PowerLiquid supports multiple dialects and host-provided extension registries
for custom tags and filters.

Before rendering, the supplied context is reduced to inert Liquid-safe data
structures.
That means templates can read scalars, arrays, hashtables, and
note-property objects, but they do not execute arbitrary PowerShell script
properties or reflective object getters from untrusted input data.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-LiquidTemplate -Template 'Hello {{ user.name }}' -Context @{ user = @{ name = 'Paul' } }
```

### EXAMPLE 2

```powershell
Invoke-LiquidTemplate -Template '{% include card.html %}' -Context @{} -Dialect JekyllLiquid -IncludeRoot .\_includes
```

## PARAMETERS

### -Template

The Liquid template source to render.

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

### -Context

The root variable scope used during rendering.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Dialect

The Liquid dialect to render with.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Liquid
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeRoot

The base path used when resolving include files.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeStack

The current include stack, primarily used internally for recursion detection.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: @()
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
Position: 6
Default value: (New-LiquidExtensionRegistry)
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.String

## NOTES

Custom tags and filters registered through the extension registry are trusted host code by design.
The template language itself does not compile or execute PowerShell from template text or context data.

## RELATED LINKS
