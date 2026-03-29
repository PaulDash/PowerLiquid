Describe 'PowerLiquid filter behavior' {
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

    It 'supports capitalize' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | capitalize }}' -Context @{}).Trim() | Should -Be 'Hello World'
    }

    It 'supports concat with arrays' {
        # Test concat by appending one array to another using context variables
        # concat: [1, 2] + [3, 4] = [1, 2, 3, 4]
        $context = @{
            array1 = @(1, 2)
            array2 = @(3, 4)
        }
        (Invoke-LiquidTemplate -Template '{{ array1 | concat: array2 | join: "," }}' -Context $context).Trim() | Should -Be '1,2,3,4'
    }

    It 'supports concat with an assigned split array argument in standard Liquid syntax' {
        $context = @{
            array1 = @('a', 'b')
        }

        $template = '{% assign array2 = "c,d" | split: "," %}{{ array1 | concat: array2 | join: "," }}'
        (Invoke-LiquidTemplate -Template $template -Context $context).Trim() | Should -Be 'a,b,c,d'
    }
    It 'supports newline_to_br' {
        (Invoke-LiquidTemplate -Template '{{ "line1\nline2" | newline_to_br }}' -Context @{}).Trim() | Should -Be 'line1<br>line2'
    }

    It 'supports remove' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | remove: "l" }}' -Context @{}).Trim() | Should -Be 'heo word'
    }

    It 'supports remove_first' {
        (Invoke-LiquidTemplate -Template '{{ "hello hello" | remove_first: "l" }}' -Context @{}).Trim() | Should -Be 'helo hello'
    }

    It 'supports remove_last' {
        (Invoke-LiquidTemplate -Template '{{ "hello hello" | remove_last: "l" }}' -Context @{}).Trim() | Should -Be 'hello helo'
    }

    It 'supports replace' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | replace: "world", "universe" }}' -Context @{}).Trim() | Should -Be 'hello universe'
    }

    It 'supports replace_first' {
        (Invoke-LiquidTemplate -Template '{{ "hello hello" | replace_first: "hello", "hi" }}' -Context @{}).Trim() | Should -Be 'hi hello'
    }

    It 'supports replace_last' {
        (Invoke-LiquidTemplate -Template '{{ "hello hello" | replace_last: "hello", "hi" }}' -Context @{}).Trim() | Should -Be 'hello hi'
    }

    It 'supports reverse for strings' {
        (Invoke-LiquidTemplate -Template '{{ "hello" | reverse }}' -Context @{}).Trim() | Should -Be 'olleh'
    }

    It 'supports reverse for arrays' {
        (Invoke-LiquidTemplate -Template '{{ "a,b,c" | split: "," | reverse | join: "," }}' -Context @{}).Trim() | Should -Be 'c,b,a'
    }

    It 'supports strip_newlines' {
        (Invoke-LiquidTemplate -Template '{{ "line1\nline2" | strip_newlines }}' -Context @{}).Trim() | Should -Be 'line1line2'
    }

    It 'supports truncate' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | truncate: 5 }}' -Context @{}).Trim() | Should -Be 'he...'
    }

    It 'supports truncate with custom suffix' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | truncate: 3, "!" }}' -Context @{}).Trim() | Should -Be 'he!'
    }

    It 'supports truncate with blank suffix' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | truncate: 5, "" }}' -Context @{}).Trim() | Should -Be 'hello'
    }

    It 'supports truncate with length longer than string' {
        (Invoke-LiquidTemplate -Template '{{ "hello world" | truncate: 20 }}' -Context @{}).Trim() | Should -Be 'hello world'
    }

    It 'supports truncatewords' {
        (Invoke-LiquidTemplate -Template '{{ "hello world from liquid" | truncatewords: 2 }}' -Context @{}).Trim() | Should -Be 'hello world...'
    }

    It 'supports sum for numeric arrays' {
        (Invoke-LiquidTemplate -Template '{{ "1,2,3,4,5" | split: "," | sum }}' -Context @{}).Trim() | Should -Be '15'
    }

    It 'supports date with format string' {
        $context = @{ createdDate = [datetime]'2026-03-29T14:30:00' }
        (Invoke-LiquidTemplate -Template '{{ createdDate | date: "yyyy-MM-dd" }}' -Context $context).Trim() | Should -Be '2026-03-29'
    }

    It 'supports date with now keyword' {
        $result = Invoke-LiquidTemplate -Template '{{ "now" | date: "yyyy" }}' -Context @{}
        $year = [datetime]::Now.Year.ToString()
        $result.Trim() | Should -Be $year
    }

    It 'supports date with today keyword' {
        $result = Invoke-LiquidTemplate -Template '{{ "today" | date: "yyyy-MM-dd" }}' -Context @{}
        $date = [datetime]::Now.ToString('yyyy-MM-dd')
        $result.Trim() | Should -Be $date
    }

}

