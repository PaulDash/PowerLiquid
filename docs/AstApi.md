# AST API

PowerLiquid exposes a parse-first API through `ConvertTo-LiquidAst`.

This is intended for:
- editors and tooling
- diagnostics
- template inspection
- host applications that need to analyze templates before rendering

## Command

```powershell
ConvertTo-LiquidAst -Template <string> [-Dialect Liquid|JekyllLiquid] [-Registry <hashtable>] [-IncludeTokens]
```

## Return Shape

`ConvertTo-LiquidAst` returns a `PowerLiquid.Ast` object.

Properties:
- `Dialect`
- `Nodes`
- `Tokens` when `-IncludeTokens` is specified

## Example

```powershell
Import-Module .\PowerLiquid.psd1

$ast = ConvertTo-LiquidAst -Template @'
{% if page.title %}
  <h1>{{ page.title }}</h1>
{% else %}
  <h1>Untitled</h1>
{% endif %}
'@ -Dialect JekyllLiquid -IncludeTokens
```

## Node Model

The `Nodes` property is a tree of PowerShell custom objects. Each node has a `Type` property and then type-specific properties.

### Text

Properties:
- `Type = 'Text'`
- `Value`

Example:

```powershell
[pscustomobject]@{
    Type  = 'Text'
    Value = 'Hello '
}
```

### Output

Properties:
- `Type = 'Output'`
- `Expression`

Represents `{{ ... }}`.

### Assign

Properties:
- `Type = 'Assign'`
- `Name`
- `Expression`

Represents `{% assign x = ... %}`.

### Capture

Properties:
- `Type = 'Capture'`
- `Name`
- `Nodes`

Represents a nested capture block.

### If

Properties:
- `Type = 'If'`
- `Branches`
- `Else`

Each `Branches` item contains:
- `Condition`
- `Nodes`

### Unless

Properties:
- `Type = 'Unless'`
- `Condition`
- `Nodes`
- `Else`

### For

Properties:
- `Type = 'For'`
- `VariableName`
- `CollectionExpression`
- `Nodes`
- `Else`

### Include

Properties:
- `Type = 'Include'`
- `TargetExpression`
- `Parameters`

This is emitted when the parser encounters `{% include ... %}`.

### CustomTag

Properties:
- `Type = 'CustomTag'`
- `Name`
- `Markup`

This is emitted when the parser recognizes a host-registered custom tag through the supplied registry.

## Tokens

When `-IncludeTokens` is used, the AST root also contains `Tokens`.

Each token includes:
- `Type`
- `Raw`
- `Value`

These are useful for debugging and future tooling, but `Nodes` should be preferred for structural analysis.

## Dialect Behavior

The AST generator validates against the selected dialect.

That means:
- unsupported dialect values throw immediately
- dialect-specific syntax such as Jekyll-style `include` can be recognized in the appropriate dialect
- host-registered custom tags are recognized through the supplied registry during parsing

## Stability Notes

The AST root shape is intended to be stable:
- `Dialect`
- `Nodes`
- optional `Tokens`

The individual node set will grow as PowerLiquid adds more Liquid features, but existing node shapes should remain compatible where practical.

## Security Notes

`ConvertTo-LiquidAst` is parse-only. It does not evaluate context data, filters, includes, or custom tag handlers.

That makes it the safest API surface for:
- editor tooling
- linting
- static inspection
- diagnostics

If you need to inspect untrusted Liquid templates without rendering them, prefer `ConvertTo-LiquidAst`.
