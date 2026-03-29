---
Module Name: PowerLiquid
Module Guid: 9b6a6ea6-f0f5-4d53-b805-ecbf32f30420
Download Help Link: {{ Update Download Link }}
Help Version: 0.2.0
Locale: en-US
---

# PowerLiquid Module

## Description

PowerLiquid is a standalone PowerShell module for parsing and rendering Liquid templates.
It supports a base `Liquid` dialect, a `JekyllLiquid` dialect, a parse-first AST API,
and a host-controlled extension model for custom tags, filters, and trusted types.

## PowerLiquid Cmdlets

### [ConvertTo-LiquidAst](ConvertTo-LiquidAst.md)

Parses a Liquid template into a structured abstract syntax tree without rendering it. This cmdlet page is the authoritative AST API reference.

### [Invoke-LiquidTemplate](Invoke-LiquidTemplate.md)

Parses and renders a Liquid template against a supplied PowerShell context.

### [New-LiquidExtensionRegistry](New-LiquidExtensionRegistry.md)

Creates a registry object used to register host-provided Liquid tags, filters, and trusted CLR types.

### [Register-LiquidFilter](Register-LiquidFilter.md)

Registers a custom Liquid filter in an extension registry for a selected dialect.

### [Register-LiquidTag](Register-LiquidTag.md)

Registers a custom Liquid tag handler in an extension registry for a selected dialect.

### [Register-LiquidTrustedType](Register-LiquidTrustedType.md)

Allows a host to explicitly expose a trusted CLR type's public properties to templates.

