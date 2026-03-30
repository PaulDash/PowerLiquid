---
external help file: PowerLiquid-help.xml
Module Name: PowerLiquid
online version:
schema: 2.0.0
---

# New-LiquidExtensionRegistry

## SYNOPSIS
Creates a Liquid extension registry.

## SYNTAX

```
New-LiquidExtensionRegistry [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Creates the registry object used to register host-provided custom tags and filters.
PowerLiquid keeps extensions separate by dialect so a host can opt in to different
behavior for core Liquid and Jekyll-style Liquid without loading plugins directly.

## EXAMPLES

### EXAMPLE 1
```
$registry = New-LiquidExtensionRegistry
```

## PARAMETERS

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable
## NOTES

## RELATED LINKS
