---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
---

# Register-LiquidTag

## SYNOPSIS

Registers a custom Liquid tag.

## SYNTAX

```powershell
Register-LiquidTag [-Registry] <Hashtable> [[-Dialect] <String>] [-Name] <String> [-Handler] <ScriptBlock>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Adds a host-provided tag handler to an extension registry for a specific dialect.
The handler is later invoked by Invoke-LiquidTemplate when the parser encounters
the matching tag name.

## EXAMPLES

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

### -Dialect

The dialect whose tag table should receive the custom tag.

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

### -Name

The tag name to register.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Handler

The script block that will render the custom tag.

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS
