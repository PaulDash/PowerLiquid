#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$configuration = New-PesterConfiguration
$configuration.Run.Path = @(
    (Join-Path -Path $PSScriptRoot -ChildPath 'PowerLiquid.Tests.ps1')
)
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestDrive.Enabled = $true
$configuration.TestRegistry.Enabled = $false

Invoke-Pester -Configuration $configuration
