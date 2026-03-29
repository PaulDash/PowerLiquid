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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([hashtable])]
    param()

    try {
        if (-not $PSCmdlet.ShouldProcess('Liquid extension registry', 'Create')) {
            return
        }

        Write-Verbose "Creating new Liquid extension registry"

        # Create the root registry object with dialect-specific tag and filter tables.
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
    } catch {
        throw "New-LiquidExtensionRegistry failed: $($_.Exception.Message)"
    }
}