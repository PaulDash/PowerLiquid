# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.13] - 2026-03-29

### Changed

- Set comment-based help as the single authored help source
- Simplified tool to regenerate markdown and external help from comment-based help
- Consolidated AST API documentation into ConvertTo-LiquidAst help and removed duplicate AST docs/about topic

### Added

- AST and token source locations for line/column-aware diagnostics
- Verbose output to all public functions for better debugging and monitoring
- Tools folder with testExecution.ps1 and testBPA.ps1 for automated testing and best practices analysis

### Fixed

- Renamed $matches variables to $regexMatches to avoid overwriting PowerShell's automatic $matches variable
- Fixed BOM encoding for PowerLiquid.psd1 to use UTF-8 with BOM

## [0.8.0] - 2026-03-28

### Added

- Contribution guidelines in README.md
- This CHANGELOG.md for tracking changes
- Public functions moved to Public/ folder for standard module structure

### Changed

- Improved context sanitization to prevent potential security issues

### Fixed

- Various parsing and rendering improvements

## [0.3.0] - 2026-03-28

### Added

- Documented AST API through `ConvertTo-LiquidAst`
- Comment-based help for public commands
- Expanded documentation for tooling and host integration

### Changed

- Enhanced dialect support and extension registry

### Fixed

- Various parsing and rendering improvements
