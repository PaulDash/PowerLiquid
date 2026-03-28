# PowerLiquid

PowerLiquid is a standalone PowerShell module for tokenizing, parsing, and rendering Liquid templates.

## Goals

- standalone Liquid engine for PowerShell
- reusable in any host application
- explicit dialect support
- host-controlled extensibility

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

PowerLiquid currently supports two dialects:

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
