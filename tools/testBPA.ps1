#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module PSScriptAnalyzer -ErrorAction Stop

$modulePath = Split-Path -Parent $PSScriptRoot

Write-Host "Running Best Practices Analyzer on PowerLiquid module..."

$results = Invoke-ScriptAnalyzer -Path $modulePath -Recurse -Severity @('Error', 'Warning', 'Information')

if ($results) {
    $results | Format-Table -AutoSize
    Write-Host "Analysis complete. $($results.Count) issues found."
} else {
    Write-Host "Analysis complete. No issues found."
}