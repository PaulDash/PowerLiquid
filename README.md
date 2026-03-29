# PowerLiquid ![PowerLiquid Icon](https://github.com/PaulDash/PowerLiquid/raw/main/res/Icon_85x85.png)

PowerLiquid is a standalone PowerShell module for tokenizing, parsing, and rendering Liquid templates.

## Goals

- standalone Liquid engine for PowerShell
- reusable in any host application
- explicit dialect support
- host-controlled extensibility

## Current Features

- Liquid template tokenization
- object output with filter pipelines including string, numeric, date, URL, and collection helpers
- custom tags and filters through an extension registry
- separate `Liquid` and `JekyllLiquid` dialects
- AST generation through `ConvertTo-LiquidAst` with token and node diagnostics

### Available commands

- `ConvertTo-LiquidAst`
- `Invoke-LiquidTemplate`
- `New-LiquidExtensionRegistry`
- `Register-LiquidTag`
- `Register-LiquidFilter`
- `Register-LiquidTrustedType`

## Quick Example

```powershell
Invoke-LiquidTemplate -Template 'Hello {{ user.name | upcase }}' -Context @{
    user = @{
        name = 'Paul'
    }
}
```

Should produce `Hello PAUL`

## Dialects

PowerLiquid currently supports two dialects:

The base `Liquid` dialect stays focused on core Liquid syntax.

The `JekyllLiquid` dialect layers Jekyll-specific behavior such as:

- Jekyll filters
- Jekyll-style {% include %}`r
- Jekyll-style {% include_relative %} when the host supplies the current file path and an allowed relative root

## Host Extension Model

PowerLiquid allows hosts to extend the template language through an extension registry. This keeps custom behavior separate from core Liquid logic.

PowerLiquid does not load plugins on its own.

Instead, a host application is expected to:

1. create an extension registry
2. register any custom tags and filters
3. pass that registry into the render call

That design keeps PowerLiquid reusable and avoids coupling it to any particular site generator or application plugin system.

## Security Model

PowerLiquid does not evaluate PowerShell from template text.

Template input is limited to Liquid parsing and rendering rules:

- object lookups
- control-flow tags
- built-in filters such as `sort`, `sort_natural`, `slice`, `strip_html`, `url_encode`, and `url_decode`
- host-registered custom tags and filters

To reduce risk from untrusted context data, `Invoke-LiquidTemplate` sanitizes the supplied context into inert Liquid-safe values before rendering. In practice that means templates can safely read:

- scalars such as strings, numbers, booleans, and datetimes
- hashtables / dictionaries
- arrays and enumerables
- note-property objects

PowerLiquid intentionally does not execute script-backed properties from context objects during variable lookup.

Important trust boundary:

- custom tags and custom filters are executable host code by design
- if a host registers a malicious script block, PowerLiquid will invoke it
- if a host registers a trusted CLR type, PowerLiquid will read that type's public properties

So the safe rule is:

- untrusted templates and untrusted data are acceptable inputs
- untrusted extension handlers are not

If a host needs to expose strongly-typed model objects, it must opt in explicitly:

```powershell
$registry = New-LiquidExtensionRegistry
Register-LiquidTrustedType -Registry $registry -TypeName HydeDocument
```

### Example: Register a Custom Tag

```powershell
$registry = New-LiquidExtensionRegistry

Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name hello -Handler {
    param($Invocation)
    return 'Hello from a host application'
}

Invoke-LiquidTemplate -Template '{% hello %}' -Context @{} -Dialect JekyllLiquid -Registry $registry
```

### Example: Register a Custom Filter

```powershell
$registry = New-LiquidExtensionRegistry

Register-LiquidFilter -Registry $registry -Dialect Liquid -Name shout -Handler {
    param($Value, $Arguments, $Invocation)
    return ([string]$Value).ToUpperInvariant() + '!'
}

Invoke-LiquidTemplate -Template '{{ "hello" | shout }}' -Context @{} -Registry $registry
```

## AST API

PowerLiquid also exposes a parse-first API:

```powershell
$ast = ConvertTo-LiquidAst -Template '{% if page.title %}{{ page.title }}{% endif %}' -Dialect JekyllLiquid
$ast.Nodes
```

The AST root is returned as a `PowerLiquid.Ast` object with:

- `Dialect`
- `Nodes`
- optional Tokens when -IncludeTokens is used

Each token and AST node now carries a Location object with StartLine, StartColumn, EndLine, EndColumn, StartIndex, and EndIndex for editor integrations and diagnostics.

## Contributing

We welcome contributions! Please follow these guidelines:

### Development Setup

1. Clone the repository.
2. Ensure PowerShell 7+ is installed.
3. Run tests: `.\tools\testExecution.ps1`
4. Run Best Practices Analyzer: `.\tools\testBPA.ps1`

### Code Style

- Use consistent PowerShell naming conventions.
- Add comment-based help for new functions.
- Write Pester tests for new features.
- Follow the existing code structure (public functions in `Public/`, private in `Private/`).

### Submitting Changes

1. Create a feature branch from `main`.
2. Make changes and add tests.
3. Run all tests and ensure they pass.
4. Update CHANGELOG.md for significant changes.
5. Submit a pull request with a clear description.

### Reporting Issues

- Use GitHub issues for bugs and feature requests.
- Include template examples, expected vs. actual output, and PowerShell version.

