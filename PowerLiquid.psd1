@{
    RootModule        = 'PowerLiquid.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '9b6a6ea6-f0f5-4d53-b805-ecbf32f30420'
    Author            = 'Paul Wojcicki-Jarocki'
    CompanyName       = 'Paul Dash'
    Copyright         = '© 2026 Paul Dash'
    Description       = 'PowerShell implementation of the Liquid templating language with dialect and extension registry support.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Invoke-LiquidTemplate'
        'New-LiquidExtensionRegistry'
        'Register-LiquidTag'
        'Register-LiquidFilter'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    FileList = @(
        'PowerLiquid.psd1'
        'PowerLiquid.psm1'
        'Private\PowerLiquid.Engine.ps1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Liquid', 'Templating', 'Jekyll', 'PowerShell')
            ProjectUri   = 'https://github.com/PaulDash/PowerLiquid'
            LicenseUri   = 'https://github.com/PaulDash/PowerLiquid/blob/main/LICENSE'
            ReleaseNotes = 'Restructured the module into a publish-ready layout with a loader module, private engine file, documentation, and test runner.'
        }
    }
}
