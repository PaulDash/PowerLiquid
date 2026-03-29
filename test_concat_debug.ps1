Remove-Module PowerLiquid -Force -ErrorAction SilentlyContinue
Import-Module .\PowerLiquid.psd1 -Force
$template = '{{ "a,b" | split: "," | concat: ("c" | split: ",") | join: "," }}'
$result = Invoke-LiquidTemplate -Template $template -Context @{}
Write-Host "Result: [$result]"
