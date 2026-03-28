# TODO

## Publishing Notes

PowerLiquid is structured like a normal gallery module:

- manifest at the repo root
- root loader module
- private implementation files
- documentation folder
- tests folder

Before first publication, the remaining release work is mostly administrative:

- add comment-based help and platyPS help output
- decide the first gallery versioning policy
- add CI for tests and ScriptAnalyzer
- publish help and examples

## Improvements

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
- add a full standalone test suite with compatibility fixtures

### Performance

- add template caching
- add precompiled template support
- reduce repeated regex/tokenization work during nested renders
