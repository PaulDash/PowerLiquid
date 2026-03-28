<#
.SYNOPSIS
Registers a custom Liquid filter.
.DESCRIPTION
Adds a host-provided filter handler to an extension registry for a specific dialect.
Filter handlers participate in the normal Liquid filter pipeline during rendering.
.PARAMETER Registry
The extension registry created by New-LiquidExtensionRegistry.
.PARAMETER Dialect
The dialect whose filter table should receive the custom filter.
.PARAMETER Name
The filter name to register.
.PARAMETER Handler
The script block that will run for the custom filter.
.EXAMPLE
Register-LiquidFilter -Registry $registry -Dialect Liquid -Name shout -Handler { param($Value) ([string]$Value).ToUpperInvariant() }
#>
function Register-LiquidFilter {
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

    # Custom filters join the normal filter pipeline and can be targeted to one dialect.
    $Registry.Dialects[$Dialect].Filters[$Name.ToLowerInvariant()] = $Handler
}