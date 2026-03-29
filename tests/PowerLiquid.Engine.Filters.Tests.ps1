Describe 'PowerLiquid numeric filter behavior' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force
    }

    It 'supports plus' {
        (Invoke-LiquidTemplate -Template '{{ 5 | plus: 3 }}' -Context @{}).Trim() | Should -Be '8'
    }

    It 'supports minus' {
        (Invoke-LiquidTemplate -Template '{{ 5 | minus: 3 }}' -Context @{}).Trim() | Should -Be '2'
    }

    It 'supports times' {
        (Invoke-LiquidTemplate -Template '{{ 5 | times: 3 }}' -Context @{}).Trim() | Should -Be '15'
    }

    It 'supports divided_by' {
        (Invoke-LiquidTemplate -Template '{{ 9 | divided_by: 3 }}' -Context @{}).Trim() | Should -Be '3'
    }

    It 'supports modulo' {
        (Invoke-LiquidTemplate -Template '{{ 10 | modulo: 3 }}' -Context @{}).Trim() | Should -Be '1'
    }

    It 'supports abs for positive values' {
        (Invoke-LiquidTemplate -Template '{{ 5 | abs }}' -Context @{}).Trim() | Should -Be '5'
    }

    It 'supports abs for negative values' {
        (Invoke-LiquidTemplate -Template '{{ -5 | abs }}' -Context @{}).Trim() | Should -Be '5'
    }

    It 'supports at_least with lower input' {
        (Invoke-LiquidTemplate -Template '{{ 3 | at_least: 5 }}' -Context @{}).Trim() | Should -Be '5'
    }

    It 'supports at_least with higher input' {
        (Invoke-LiquidTemplate -Template '{{ 7 | at_least: 5 }}' -Context @{}).Trim() | Should -Be '7'
    }

    It 'supports at_most with higher input' {
        (Invoke-LiquidTemplate -Template '{{ 7 | at_most: 5 }}' -Context @{}).Trim() | Should -Be '5'
    }

    It 'supports at_most with lower input' {
        (Invoke-LiquidTemplate -Template '{{ 3 | at_most: 5 }}' -Context @{}).Trim() | Should -Be '3'
    }

    It 'supports floor' {
        (Invoke-LiquidTemplate -Template '{{ 3.9 | floor }}' -Context @{}).Trim() | Should -Be '3'
    }

    It 'supports round half up default precision' {
        (Invoke-LiquidTemplate -Template '{{ 3.5 | round }}' -Context @{}).Trim() | Should -Be '4'
    }

    It 'supports round with precision argument' {
        (Invoke-LiquidTemplate -Template '{{ 3.14159 | round: 2 }}' -Context @{}).Trim() | Should -Be '3.14'
    }
}
