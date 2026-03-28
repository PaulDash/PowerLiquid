# PowerLiquid

PowerLiquid is a standalone PowerShell module for tokenizing, parsing, and rendering Liquid templates.

It was extracted from Hyde so the Liquid engine can evolve independently, be versioned on its own, and be reused in other PowerShell projects that need Liquid syntax without adopting Hyde itself.

## Goals

- standalone Liquid engine for PowerShell
- reusable in any host application
- explicit dialect support
- host-controlled extensibility
- publishable as a normal PowerShell module

## Current Features

- Liquid template tokenization
- object output with filter pipelines
- control-flow tags such as `if`, `elsif`, `else`, `unless`, and `for`
- `assign` and `capture`
- `comment` and `raw`
- `include` support in the `JekyllLiquid` dialect
- custom tags and filters through an extension registry
- separate `Liquid` and `JekyllLiquid` dialects
- a practical starter set of built-in filters

## Installation

Once published, install it from the PowerShell Gallery:

```powershell
Install-Module PowerLiquid
```

For local development:

```powershell
Import-Module .\PowerLiquid.psd1
```

## Quick Example

```powershell
Import-Module .\PowerLiquid.psd1

$result = Invoke-LiquidTemplate -Template 'Hello {{ user.name | upcase }}' -Context @{
    user = @{
        name = 'Paul'
    }
}

$result
```

## Dialects

PowerLiquid currently supports:

- `Liquid`
- `JekyllLiquid`

The base `Liquid` dialect stays focused on core Liquid syntax.

The `JekyllLiquid` dialect layers Jekyll-specific behavior such as:
- Jekyll filters
- Jekyll-style `{% include %}`

## Host Extension Model

PowerLiquid does not load plugins on its own.

Instead, a host application is expected to:
1. create an extension registry
2. register any custom tags and filters
3. pass that registry into the render call

That design keeps PowerLiquid reusable and avoids coupling it to any particular site generator or application plugin system.

### Example: Register a Custom Tag

```powershell
Import-Module .\PowerLiquid.psd1

$registry = New-LiquidExtensionRegistry

Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name hello -Handler {
    param($Invocation)
    return 'Hello from a host application'
}

Invoke-LiquidTemplate -Template '{% hello %}' -Context @{} -Dialect JekyllLiquid -Registry $registry
```

### Example: Register a Custom Filter

```powershell
Import-Module .\PowerLiquid.psd1

$registry = New-LiquidExtensionRegistry

Register-LiquidFilter -Registry $registry -Dialect Liquid -Name shout -Handler {
    param($Value, $Arguments, $Invocation)
    return ([string]$Value).ToUpperInvariant() + '!'
}

Invoke-LiquidTemplate -Template '{{ "hello" | shout }}' -Context @{} -Registry $registry
```

## Public API

- `Invoke-LiquidTemplate`
- `New-LiquidExtensionRegistry`
- `Register-LiquidTag`
- `Register-LiquidFilter`

## Repository Layout

```text
PowerLiquid/
  PowerLiquid.psd1
  PowerLiquid.psm1
  Public/
  Private/
    PowerLiquid.Engine.ps1
  docs/
  tests/
```

The root module is now a loader, while the engine lives in `Private/PowerLiquid.Engine.ps1`. That keeps the module ready for future internal splitting without breaking the public API.

## Publishing Notes

PowerLiquid is structured like a normal gallery module:
- manifest at the repo root
- root loader module
- private implementation files
- documentation folder
- tests folder

Before first publication, the remaining release work is mostly administrative:
- decide the first gallery versioning policy
- add CI for tests and ScriptAnalyzer
- publish help and examples

## Suggested Improvements

PowerLiquid is already useful, but these would make it much more broadly reusable:

### Parser and AST

- expose a parse-only API in addition to render
- expose an AST / token tree for tooling use
- preserve line and column information for diagnostics

### Compatibility

- add more Liquid tags such as `render`, `tablerow`, `case`, `cycle`, `increment`, and `decrement`
- add more standard filters and stricter compatibility behavior
- support whitespace-control edge cases more completely

### Host Integration

- provide explicit callback hooks for file resolution instead of only built-in include-root handling
- support host-provided error policies such as strict variables, strict filters, or warnings-only
- make dialect definitions data-driven so hosts can define custom dialects

### Tooling

- add parse diagnostics with structured error records
- add formatter / linter support
- add comment-based help and platyPS help output
- add a full standalone test suite with compatibility fixtures

### Performance

- add template caching
- add precompiled template support
- reduce repeated regex/tokenization work during nested renders

## Relationship to Hyde

Hyde uses PowerLiquid as its Liquid engine, but Hyde remains responsible for:
- plugin discovery
- site/document modeling
- layout resolution
- file system concerns

PowerLiquid stays focused on Liquid parsing and rendering.
