Describe 'PowerLiquid advanced engine tags' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force
    }

    It 'supports case, cycle, increment, and decrement tags' {
        $template = "{% case page.kind %}{% when 'note', 'post' %}kind{% else %}other{% endcase %}|{% cycle 'odd', 'even' %}|{% cycle 'odd', 'even' %}|{% increment counter %}|{% increment counter %}|{% decrement counter %}"
        $result = Invoke-LiquidTemplate -Template $template -Context @{ page = @{ kind = 'note' } }
        $result | Should -Be 'kind|odd|even|0|1|1'
    }

    It 'supports break and continue inside for loops' {
        $template = "{% for item in items %}{% if item == 2 %}{% continue %}{% endif %}{{ item }}{% if item == 3 %}{% break %}{% endif %}{% endfor %}"
        $result = Invoke-LiquidTemplate -Template $template -Context @{ items = @(1, 2, 3, 4) }
        $result | Should -Be '13'
    }

    It 'supports tablerow output' {
        $template = "{% tablerow item in items cols:2 %}{{ item }}{% endtablerow %}"
        $result = Invoke-LiquidTemplate -Template $template -Context @{ items = @('a', 'b', 'c') }
        $result | Should -Be '<tr class=""row1""><td class=""col1"">a</td><td class=""col2"">b</td></tr><tr class=""row2""><td class=""col1"">c</td></tr>'
    }
    It 'supports forloop properties including parentloop in nested loops' {
        $template = '{% for row in rows %}[{{ forloop.index }}/{{ forloop.length }}/{{ forloop.first }}/{{ forloop.last }}:{% for cell in row %}{{ forloop.parentloop.index }}.{{ forloop.index0 }}.{{ forloop.rindex0 }}{% unless forloop.last %},{% endunless %}{% endfor %}]{% endfor %}'
        $context = @{ rows = @(@('a', 'b'), @('c')) }
        $result = Invoke-LiquidTemplate -Template $template -Context $context
        $result | Should -Be '[1/2/True/False:1.0.1,1.1.0][2/2/False/True:2.0.0]'
    }

    It 'supports tablerowloop row and column properties' {
        $template = '{% tablerow item in items cols:2 %}{{ tablerowloop.row }}:{{ tablerowloop.col }}:{{ tablerowloop.col_first }}:{{ tablerowloop.col_last }}:{{ tablerowloop.index0 }}:{{ tablerowloop.rindex }}{% endtablerow %}'
        $result = Invoke-LiquidTemplate -Template $template -Context @{ items = @('a', 'b', 'c') }
        $result | Should -Be '<tr class=""row1""><td class=""col1"">1:1:True:False:0:3</td><td class=""col2"">1:2:False:True:1:2</td></tr><tr class=""row2""><td class=""col1"">2:1:True:True:2:1</td></tr>'
    }

    It 'rejects break outside loop constructs' {
        { Invoke-LiquidTemplate -Template '{% break %}' -Context @{} } | Should -Throw -ExpectedMessage '*break tag can only be used inside for or tablerow loops*'
    }

    It 'parses AST nodes for case and loop-control tags' {
        $template = "{% case page.kind %}{% when 'note' %}x{% endcase %}{% cycle 'odd', 'even' %}{% increment count %}{% decrement count %}"
        $ast = ConvertTo-LiquidAst -Template $template -Dialect JekyllLiquid
        $ast.Nodes[0].Type | Should -Be 'Case'
        $ast.Nodes[1].Type | Should -Be 'Cycle'
        $ast.Nodes[2].Type | Should -Be 'Increment'
        $ast.Nodes[3].Type | Should -Be 'Decrement'
    }
}

