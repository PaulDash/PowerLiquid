---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
---

# Register-LiquidFilter

## SYNOPSIS

Registers a custom Liquid filter.

## SYNTAX

```powershell
Register-LiquidFilter [-Registry] <Hashtable> [[-Dialect] <String>] [-Name] <String> [-Handler] <ScriptBlock>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Adds a host-provided filter handler to an extension registry for a specific dialect.
Filter handlers participate in the normal Liquid filter pipeline during rendering.

## EXAMPLES

### EXAMPLE 1

```powershell
Register-LiquidFilter -Registry $registry -Dialect Liquid -Name shout -Handler { param($Value) ([string]$Value).ToUpperInvariant() }
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

### -Dialect

The dialect whose filter table should receive the custom filter.

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

The filter name to register.

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

The script block that will run for the custom filter.

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
