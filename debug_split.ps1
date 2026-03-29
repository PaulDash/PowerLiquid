. .\PowerLiquid.psm1
$trimmedSegment = 'truncate: 3, "!"'
$filterParts = Split-LiquidDelimitedString -InputText $trimmedSegment -Delimiter ':'
Write-Host "filterParts count=$($filterParts.Count)"
for ($i=0; $i -lt $filterParts.Count; $i++) { Write-Host "filterParts[$i]=[$($filterParts[$i])]" }
$argumentExpressions = @(Split-LiquidDelimitedString -InputText ([string]$filterParts[1]) -Delimiter ',' | ForEach-Object {[string]$_})
Write-Host "argumentExpressions count=$($argumentExpressions.Count)"
for ($i=0; $i -lt $argumentExpressions.Count; $i++) { Write-Host "argumentExpressions[$i]=[$($argumentExpressions[$i])]" }
