---
Module Name: PowerLiquid
Module Guid: 9b6a6ea6-f0f5-4d53-b805-ecbf32f30420
Download Help Link: https://github.com/PaulDash/PowerLiquid/docs
Help Version: 1.0.0
Locale: en-US
---

# PowerLiquid Module
## Description
PowerLiquid is a PowerShell implementation of the Liquid templating language with support for multiple dialects, extensible tags and filters, and safe host-controlled rendering.

## PowerLiquid Cmdlets
### [ConvertTo-LiquidAst](ConvertTo-LiquidAst.md)
Tokenizes and parses a Liquid template into a structured Abstract Syntax Tree (AST) for analysis, diagnostics, and tooling.

### [Invoke-LiquidTemplate](Invoke-LiquidTemplate.md)
Parses and renders a Liquid template against a supplied context using the selected dialect, built-in features, and any registered extensions.

### [New-LiquidExtensionRegistry](New-LiquidExtensionRegistry.md)
Creates an extension registry that stores host-provided filters, tags, and trusted types for PowerLiquid.

### [Register-LiquidFilter](Register-LiquidFilter.md)
Adds a custom filter handler to an extension registry so it can participate in the normal Liquid filter pipeline during rendering.

### [Register-LiquidTag](Register-LiquidTag.md)
Adds a custom tag handler to an extension registry so PowerLiquid can invoke it when the matching tag is encountered.

### [Register-LiquidTrustedType](Register-LiquidTrustedType.md)
Registers a CLR type as trusted so its public properties can be exposed to Liquid templates without reducing it to inert data first.
