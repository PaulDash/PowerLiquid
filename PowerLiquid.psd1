@{
    RootModule        = 'PowerLiquid.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '9b6a6ea6-f0f5-4d53-b805-ecbf32f30420'
    Author            = 'Paul Dash'
    CompanyName       = 'Paul Dash'
    Copyright         = '© 2026 Paul Dash'
    Description       = 'Implementation of the Liquid templating language with multiple dialects and support for extensions.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'ConvertTo-LiquidAst'
        'Invoke-LiquidTemplate'
        'New-LiquidExtensionRegistry'
        'Register-LiquidTag'
        'Register-LiquidFilter'
        'Register-LiquidTrustedType'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList = @(
        'README.md'
        'LICENSE.md'
        'PowerLiquid.psd1'
        'PowerLiquid.psm1'
        'Private\PowerLiquid.Engine.ps1'
        'Public\ConvertTo-LiquidAst.ps1'
        'Public\Invoke-LiquidTemplate.ps1'
        'Public\New-LiquidExtensionRegistry.ps1'
        'Public\Register-LiquidFilter.ps1'
        'Public\Register-LiquidTag.ps1'
        'Public\Register-LiquidTrustedType.ps1'
        'en-US\PowerLiquid-help.xml'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Liquid', 'Template', 'TemplateEngine', 'PSEdition_Core')
            ProjectURI   = 'https://github.com/PaulDash/PowerLiquid'
            LicenseURI   = 'https://github.com/PaulDash/PowerLiquid/raw/main/LICENSE.md'
            IconURI      = 'https://github.com/PaulDash/PowerLiquid/raw/main/res/Icon_85x85.png'
            ReleaseNotes = 'PowerLiquid is a standalone PowerShell module for tokenizing, parsing, and rendering Liquid templates.

Goals:
- reusable in any host application
- explicit dialect support
- host-controlled extensibility

# 1.0.0

Everything that is in Liquid documentation (at https://shopify.github.io/liquid/) - so all object types, tags, and filters - is working.

- Liquid template tokenization
- object output with the full current built-in filter set across string, numeric, date, URL, and collection helpers
- custom tags and filters through an extension registry
- separate `Liquid` and `JekyllLiquid` dialects
- AST generation  with token and node diagnostics
- consistent top-level error handling across the exported commands
'
        }
    }
}
