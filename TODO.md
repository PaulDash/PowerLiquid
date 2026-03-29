# Future improvements

## Features

### Parser and AST

- expose a parse-only API in addition to render
- expose an AST / token tree for tooling use

### Compatibility

- add "forloop", "tablerowloop", "echo", and "render" tag support
- add "liquid" tag support (from Liquid version 5.0.0)
- support for inline comments inside tags (from version 5.4.0)
- add "EmptyDrop" object type
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
