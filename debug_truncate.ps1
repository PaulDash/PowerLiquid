Remove-Module PowerLiquid -Force -ErrorAction SilentlyContinue
Import-Module .\PowerLiquid.psd1 -Force

# Test via Invoke-LiquidTemplate (public API)
$result1 = Invoke-LiquidTemplate -Template '{{ "hello world" | truncate: 3, "!" }}' -Context @{}
Write-Host "Template result 1: [$result1]"

$result2 = Invoke-LiquidTemplate -Template '{{ "hello world" | truncate: 5 }}' -Context @{}
Write-Host "Template result 2: [$result2]"

$result3 = Invoke-LiquidTemplate -Template '{{ "hello world" | replace: "world", "universe" }}' -Context @{}
Write-Host "Template result 3: [$result3]"
