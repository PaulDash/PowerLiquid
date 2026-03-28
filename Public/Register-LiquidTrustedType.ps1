<#
.SYNOPSIS
Registers a trusted CLR type for object-property access.
.DESCRIPTION
By default, PowerLiquid sanitizes host-provided data down to inert scalars,
collections, hashtables, and note-property objects. If a host application wants
to expose a specific CLR type's public properties to templates, it must opt in
explicitly by registering that type as trusted.

This keeps untrusted input safe by default while still allowing trusted host
models, such as strongly-typed document objects, to participate in templates.
.PARAMETER Registry
The extension registry created by New-LiquidExtensionRegistry.
.PARAMETER TypeName
The CLR type name to trust. Both full names and short names are matched.
.EXAMPLE
Register-LiquidTrustedType -Registry $registry -TypeName HydeDocument
#>
function Register-LiquidTrustedType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [string]$TypeName
    )

    if (-not $Registry.ContainsKey('TrustedTypes') -or $null -eq $Registry.TrustedTypes) {
        $Registry.TrustedTypes = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    }

    Write-Verbose "Registering trusted type '$TypeName' for object-property access"

    [void]$Registry.TrustedTypes.Add($TypeName)

    Write-Verbose "Trusted type '$TypeName' registered successfully"
}