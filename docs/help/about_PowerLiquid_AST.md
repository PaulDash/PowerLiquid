# PowerLiquid_AST
## about_PowerLiquid_AST

# SHORT DESCRIPTION

Describes the PowerLiquid abstract syntax tree (AST) API exposed by ConvertTo-LiquidAst.

# LONG DESCRIPTION

PowerLiquid exposes a parse-first API through ConvertTo-LiquidAst.

This API is intended for:

- editors and tooling
- diagnostics
- template inspection
- host applications that need to analyze templates before rendering

ConvertTo-LiquidAst returns a PowerLiquid.Ast object. The root object contains:

- Dialect
- Nodes
- Tokens (when -IncludeTokens is specified)

The Nodes property is a tree of PowerShell custom objects. Each node contains a Type
property and then type-specific properties.

Current node types include:

- Text
- Output
- Assign
- Capture
- If
- Unless
- For
- Include
- CustomTag

The AST generator validates against the selected dialect. That means unsupported dialect
values fail immediately, and dialect-specific syntax such as Jekyll-style 'include' is only
recognized when appropriate.

ConvertTo-LiquidAst is parse-only. It does not evaluate context data, filters, includes,
or custom tag handlers. If you need to inspect untrusted Liquid templates without rendering
them, prefer the AST API over the render API.

# EXAMPLES

## Example 1: Parse a template into an AST

```powershell
Import-Module .\PowerLiquid.psd1

$template = @'
{% if page.title %}
  <h1>{{ page.title }}</h1>
{% else %}
  <h1>Untitled</h1>
{% endif %}
'@

$ast = ConvertTo-LiquidAst -Template $template -Dialect JekyllLiquid -IncludeTokens
$ast.Nodes
```

Stores a small Liquid template in $template, parses that template into an abstract syntax tree, and then displays the parsed node structure from $ast.Nodes instead of rendering HTML.

# KEYWORDS

- PowerLiquid_API
- Liquid_API
