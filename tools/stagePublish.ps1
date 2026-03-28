$Key = Read-Host -Prompt "Enter the key to publish the module (or press Enter to skip publishing)"

if (-not [string]::IsNullOrEmpty($Key)) {
    Write-Verbose "Publishing module to PowerShell Gallery with key '$Key'..."
    Publish-Module -Path (Split-Path -Parent $PSScriptRoot) -NuGetApiKey $Key -Verbose
} else {
    Write-Verbose "No key entered. Skipping publish step."
}

# Create repository and publish
$lr = 'LocalRepository'

New-Item -Path S:\ -Name $lr -ItemType Directory
New-SmbShare -Name $lr -Path "S:\$lr" -FullAccess Administrators -ReadAccess Everyone

Register-PSRepository -Name $lr -SourceLocation "\\BOB\$lr" -InstallationPolicy Trusted

# REMEMBER to remove the HelpSource directory before publishing!
Publish-Module -Path . -Repository $lr -Exclude 'docs\*', 'tools\*', 'res\*', 'tests\*', .\TODO.md, .\.git, .\.github, .\README.md -Verbose

break

### Repository Cleanup
Unregister-PSRepository -Name $lr
Remove-SmbShare -Name $lr -Force
Remove-Item "S:\$lr" -Recurse -Force