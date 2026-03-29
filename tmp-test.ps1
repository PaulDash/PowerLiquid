$text="hello world"
$length=3
$suffix='!'
$truncatedLength=$length - $suffix.Length
write-output "suffix.Length=$($suffix.Length)"
write-output "truncatedLength=$truncatedLength"
write-output "result=$($text.Substring(0,$truncatedLength)+$suffix)"
