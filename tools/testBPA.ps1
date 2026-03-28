#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module PSScriptAnalyzer -ErrorAction Stop

$modulePath = Split-Path -Parent $PSScriptRoot

Write-Verbose "Running Best Practices Analyzer on PowerLiquid module..."

$results = Invoke-ScriptAnalyzer -Path $modulePath -Recurse -Severity @('Error', 'Warning', 'Information')

if ($results) {
    $results | Format-Table -AutoSize
    Write-Verbose "Analysis complete. $($results.Count) issues found."
} else {
    Write-Verbose "Analysis complete. No issues found."
}