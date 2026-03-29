$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Dot-source the module
. .\PowerLiquid.psm1

# Test the truncate filter directly
$text = 'hello world'
$length = 5
$suffix = '!!!'

Write-Host "Input text: '$text'"
Write-Host "Text length: $($text.Length)"
Write-Host "Truncate length: $length"
Write-Host "Suffix: '$suffix'"

if ($text.Length -le $length) {
    Write-Host "Text is short enough, no truncation needed"
} else {
    $result = $text.Substring(0, $length) + $suffix
    Write-Host "Truncated result: '$result'"
}

# Now test with the actual template
Write-Host "`nTesting with template:"
$template = '{{ "hello world" | truncate: 5, "!!!" }}'
Write-Host "Template: $template"

try {
    $result = Invoke-LiquidTemplate -Template $template -Context @{}
    Write-Host "Result: '$result'"
    Write-Host "Result trimmed: '$($result.Trim())'"
} catch {
    Write-Host "ERROR: $_"
    Write-Host "Details: $($_.Exception)"
}

# Test replace filter
Write-Host "`nTesting replace filter:"
$template2 = '{{ "hello world" | replace: "world", "universe" }}'
Write-Host "Template: $template2"

try {
    $result2 = Invoke-LiquidTemplate -Template $template2 -Context @{}
    Write-Host "Result: '$result2'"
} catch {
    Write-Host "ERROR: $_"
    Write-Host "Details: $($_.Exception)"
}
