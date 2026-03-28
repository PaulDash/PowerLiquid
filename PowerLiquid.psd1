@{
    RootModule        = 'PowerLiquid.psm1'
    ModuleVersion     = '0.1.1'
    GUID              = '9b6a6ea6-f0f5-4d53-b805-ecbf32f30420'
    Author            = 'Paul Wojcicki-Jarocki'
    CompanyName       = 'Paul Dash'
    Copyright         = '(c) Paul Dash. All rights reserved.'
    Description       = 'PowerShell implementation of the Liquid templating language with dialect and extension registry support.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-LiquidTemplate',
        'New-LiquidExtensionRegistry',
        'Register-LiquidTag',
        'Register-LiquidFilter'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Liquid', 'Templating', 'Jekyll', 'PowerShell')
            ProjectUri = 'https://github.com/pauldash/PowerLiquid'
            LicenseUri = 'https://github.com/pauldash/PowerLiquid/blob/main/LICENSE'
        }
    }
}
