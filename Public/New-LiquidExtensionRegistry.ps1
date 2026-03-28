<#
.SYNOPSIS
Creates a Liquid extension registry.
.DESCRIPTION
Creates the registry object used to register host-provided custom tags and filters.
PowerLiquid keeps extensions separate by dialect so a host can opt in to different
behavior for core Liquid and Jekyll-style Liquid without loading plugins directly.
.OUTPUTS
System.Collections.Hashtable
.EXAMPLE
$registry = New-LiquidExtensionRegistry
#>
function New-LiquidExtensionRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    Write-Verbose "Creating new Liquid extension registry"

    # Each dialect keeps separate custom tags and filters so extensions can stay dialect-specific.
    $registry = @{
        TrustedTypes = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        Dialects = @{
            Liquid = @{
                Tags    = @{}
                Filters = @{}
            }
            JekyllLiquid = @{
                Tags    = @{}
                Filters = @{}
            }
        }
    }

    Write-Verbose "Extension registry created with support for Liquid and JekyllLiquid dialects"
    return $registry
}