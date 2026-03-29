#Requires -Version 7.0

[CmdletBinding()]
param(
    [string[]]$Path = @(
        (Join-Path -Path $PSScriptRoot -ChildPath '..\tests\*.Tests.ps1')
    )
)

$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$configuration = New-PesterConfiguration
$configuration.Run.Path = @($Path)
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestDrive.Enabled = $true
$configuration.TestRegistry.Enabled = $false

Invoke-Pester -Configuration $configuration
