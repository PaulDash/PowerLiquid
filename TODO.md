# Future improvements

## Features

### Parser and AST

- expose a parse-only API in addition to render
- expose an AST / token tree for tooling use

### Compatibility

- add more Liquid tags
- add more Liquid filters and stricter compatibility behavior
- support whitespace-control edge cases more completely

### Host Integration

- provide explicit callback hooks for file resolution instead of only built-in include-root handling
- support host-provided error policies such as strict variables, strict filters, or warnings-only
- make dialect definitions data-driven so hosts can define custom dialects

### Tooling

- add parse diagnostics with structured error records
- add formatter / linter support

## Performance

- add template caching
- add precompiled template support
- reduce repeated regex/tokenization work during nested renders
