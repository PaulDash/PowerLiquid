<#
.SYNOPSIS
Registers a custom Liquid tag.
.DESCRIPTION
Adds a host-provided tag handler to an extension registry for a specific dialect.
The handler is later invoked by Invoke-LiquidTemplate when the parser encounters
the matching tag name.
.PARAMETER Registry
The extension registry created by New-LiquidExtensionRegistry.
.PARAMETER Dialect
The dialect whose tag table should receive the custom tag.
.PARAMETER Name
The tag name to register.
.PARAMETER Handler
The script block that will render the custom tag.
.EXAMPLE
Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name seo -Handler { param($Invocation) '<title>Example</title>' }
#>
function Register-LiquidTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [string]$Dialect,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Handler
    )

    if (-not $Registry.Dialects.ContainsKey($Dialect)) {
        throw "Liquid dialect '$Dialect' is not supported yet."
    }

    Write-Verbose "Registering custom tag '$Name' for dialect '$Dialect'"

    # Custom tags plug into the parser as single inline tags such as {% seo %}.
    $Registry.Dialects[$Dialect].Tags[$Name.ToLowerInvariant()] = $Handler

    Write-Verbose "Custom tag '$Name' registered successfully"
}
