Describe 'PowerLiquid operator behavior' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'src/PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force
    }

    It 'supports the equality operator' {
        (Invoke-LiquidTemplate -Template '{% if left == right %}match{% else %}miss{% endif %}' -Context @{ left = 4; right = 4 }).Trim() | Should -Be 'match'
    }

    It 'supports the inequality operator' {
        (Invoke-LiquidTemplate -Template '{% if left != right %}match{% else %}miss{% endif %}' -Context @{ left = 4; right = 5 }).Trim() | Should -Be 'match'
    }

    It 'supports the greater-than operator' {
        (Invoke-LiquidTemplate -Template '{% if left > right %}match{% else %}miss{% endif %}' -Context @{ left = 5; right = 4 }).Trim() | Should -Be 'match'
    }

    It 'supports the less-than operator' {
        (Invoke-LiquidTemplate -Template '{% if left < right %}match{% else %}miss{% endif %}' -Context @{ left = 4; right = 5 }).Trim() | Should -Be 'match'
    }

    It 'supports the greater-than-or-equal operator' {
        (Invoke-LiquidTemplate -Template '{% if left >= right %}match{% else %}miss{% endif %}' -Context @{ left = 5; right = 5 }).Trim() | Should -Be 'match'
    }

    It 'supports the less-than-or-equal operator' {
        (Invoke-LiquidTemplate -Template '{% if left <= right %}match{% else %}miss{% endif %}' -Context @{ left = 5; right = 5 }).Trim() | Should -Be 'match'
    }

    It 'supports contains for strings' {
        (Invoke-LiquidTemplate -Template '{% if text contains fragment %}match{% else %}miss{% endif %}' -Context @{ text = 'PowerLiquid'; fragment = 'Liquid' }).Trim() | Should -Be 'match'
    }

    It 'supports contains for arrays' {
        (Invoke-LiquidTemplate -Template '{% if items contains target %}match{% else %}miss{% endif %}' -Context @{ items = @('a', 'b', 'c'); target = 'b' }).Trim() | Should -Be 'match'
    }

    It 'supports and as a logical operator' {
        (Invoke-LiquidTemplate -Template '{% if left and right %}match{% else %}miss{% endif %}' -Context @{ left = $true; right = $true }).Trim() | Should -Be 'match'
    }

    It 'supports or as a logical operator' {
        (Invoke-LiquidTemplate -Template '{% if left or right %}match{% else %}miss{% endif %}' -Context @{ left = $false; right = $true }).Trim() | Should -Be 'match'
    }

    It 'evaluates logical operators from right to left' {
        (Invoke-LiquidTemplate -Template '{% if true or false and false %}match{% else %}miss{% endif %}' -Context @{}).Trim() | Should -Be 'match'
    }

    It 'does not support parentheses in conditions' {
        { Invoke-LiquidTemplate -Template '{% if (true or false) and false %}match{% endif %}' -Context @{} } | Should -Throw
    }
}
