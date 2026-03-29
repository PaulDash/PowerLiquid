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
}
