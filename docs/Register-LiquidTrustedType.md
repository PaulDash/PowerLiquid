---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
---

# Register-LiquidTrustedType

## SYNOPSIS
Registers a trusted CLR type for object-property access.

## SYNTAX

```
Register-LiquidTrustedType [-Registry] <Hashtable> [-TypeName] <String> [<CommonParameters>]
```

## DESCRIPTION
By default, PowerLiquid sanitizes host-provided data down to inert scalars,
collections, hashtables, and note-property objects.
If a host application wants
to expose a specific CLR type's public properties to templates, it must opt in
explicitly by registering that type as trusted.

This keeps untrusted input safe by default while still allowing trusted host
models, such as strongly-typed document objects, to participate in templates.

## EXAMPLES

### EXAMPLE 1
```
Register-LiquidTrustedType -Registry $registry -TypeName HydeDocument
```

## PARAMETERS

### -Registry
The extension registry created by New-LiquidExtensionRegistry.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TypeName
The CLR type name to trust.
Both full names and short names are matched.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
