Describe 'PowerLiquid advanced engine tags' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'src/PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force
    }

   It 'renders assign and if tags' {
        $template = '{% assign greeting = "Hello" %}{% if page.title == "Home" %}{{ greeting }}, {{ page.title | downcase }}{% endif %}'
        $context = @{
            page = @{
                title = 'Home'
            }
        }
        $result = Invoke-LiquidTemplate -Template $template -Context $context
        $result | Should -Be 'Hello, home'
    }

    It 'supports case, cycle, increment, decrement, echo, and render tags' {
        $template = "{% case page.kind %}{% when 'note', 'post' %}kind{% else %}other{% endcase %}|{% cycle 'odd', 'even' %}|{% cycle 'odd', 'even' %}|{% increment counter %}|{% increment counter %}|{% decrement counter %}|{% echo page.kind | upcase %}"
        $result = Invoke-LiquidTemplate -Template $template -Context @{ page = @{ kind = 'note' } }
        $result | Should -Be 'kind|odd|even|0|1|1|NOTE'
    }

    It 'supports for else when a collection is empty' {
        $template = '{% for item in page.items %}[{{ item }}]{% else %}[empty]{% endfor %}'
        $context = @{
            page = @{
                items = @()
            }
        }

        $result = Invoke-LiquidTemplate -Template $template -Context $context
        $result | Should -Be '[empty]'
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

    It 'supports for loops and forloop metadata' {
        $template = '{% for item in page.items %}[{{ forloop.index }}:{{ item }}{% if forloop.last %}:last{% endif %}]{% else %}[empty]{% endfor %}'
        $context = @{
            page = @{
                items = @('one', 'two')
            }
        }
        $result = Invoke-LiquidTemplate -Template $template -Context $context
        $result | Should -Be '[1:one][2:two:last]'
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

    It 'supports render with isolated scope and for/as bindings' {
        $templateRoot = Join-Path -Path $TestDrive -ChildPath 'render-isolation'
        [void](New-Item -Path $templateRoot -ItemType Directory -Force)
        Set-Content -LiteralPath (Join-Path $templateRoot 'card.liquid') -Encoding UTF8 -Value '{% assign local = "inner" %}{{ item }}-{{ extra }}-{{ forloop.index }}'
        $template = '{% assign hidden = "secret" %}{% render "card" for items as item, extra: "x" %}|{{ local }}|{{ hidden }}'
        $result = Invoke-LiquidTemplate -Template $template -Context @{ items = @("a", "b") } -IncludeRoot $templateRoot
        $result.Replace("`r", "").Replace("`n", "") | Should -Be 'a-x-1b-x-2||secret'
    }

    It 'supports include in the JekyllLiquid dialect with include variables' {
        $includeRoot = Join-Path -Path $TestDrive -ChildPath 'includes'
        [void](New-Item -Path $includeRoot -ItemType Directory -Force)
        Set-Content -LiteralPath (Join-Path -Path $includeRoot -ChildPath 'card.html') -Encoding UTF8 -Value 'Card: {{ include.title }} / {{ page.title }}'

        $template = 'Before {% include card.html title=page.title %} After'
        $context = @{
            page = @{
                title = 'Home'
            }
        }

        $result = Invoke-LiquidTemplate -Template $template -Context $context -Dialect 'JekyllLiquid' -IncludeRoot $includeRoot
        $result | Should -Match 'Before Card: Home / Home\s+After'
    }

    It 'warns and ignores include in the plain Liquid dialect' {
        $includeRoot = Join-Path -Path $TestDrive -ChildPath 'includes'
        [void](New-Item -Path $includeRoot -ItemType Directory -Force)
        Set-Content -LiteralPath (Join-Path -Path $includeRoot -ChildPath 'card.html') -Encoding UTF8 -Value 'Card'

        $stream = & {
            Invoke-LiquidTemplate -Template '{% include card.html %}X' -Context @{} -IncludeRoot $includeRoot
        } 3>&1

        ($stream | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Count | Should -Be 1
        ($stream | Where-Object { $_ -is [string] } | Select-Object -Last 1) | Should -Be 'X'
    }

    It 'rejects include inside a template rendered with render' {
        $templateRoot = Join-Path -Path $TestDrive -ChildPath 'render-include-ban'
        [void](New-Item -Path $templateRoot -ItemType Directory -Force)
        Set-Content -LiteralPath (Join-Path $templateRoot 'outer.liquid') -Encoding UTF8 -Value '{% include part.txt %}'
        Set-Content -LiteralPath (Join-Path $templateRoot 'part.txt') -Encoding UTF8 -Value 'part'
        { Invoke-LiquidTemplate -Template '{% render "outer" %}' -Context @{} -Dialect JekyllLiquid -IncludeRoot $templateRoot } | Should -Throw -ExpectedMessage '*include*cannot be used inside a template rendered with ''render''*'
    }
    It 'rejects break outside loop constructs' {
        { Invoke-LiquidTemplate -Template '{% break %}' -Context @{} } | Should -Throw -ExpectedMessage '*break tag can only be used inside for or tablerow loops*'
    }

    It 'supports the liquid tag with multiline logic and echo output' {
        $template = "{% liquid`nassign kind = page.kind`nif kind == 'note'`n  echo kind | upcase`nelse`n  echo 'other'`nendif %}"
        $result = Invoke-LiquidTemplate -Template $template -Context @{ page = @{ kind = 'note' } }
        $result | Should -Be 'NOTE'
    }

    It 'supports comment and raw tags' {
        $template = 'A{% comment %}ignore me{% endcomment %}B{% raw %}{{ untouched }}{% endraw %}'
        $context = @{}

        $result = Invoke-LiquidTemplate -Template $template -Context $context
        $result | Should -Be 'AB{{ untouched }}'
    }

    It 'supports standalone multi-line inline comments' {
        $template = "Before{%`n  # first line`n  # second line`n%}After"
        $result = Invoke-LiquidTemplate -Template $template -Context @{}
        $result | Should -Be 'BeforeAfter'
    }

    It 'supports standalone multi-line inline comments with whitespace control' {
        $template = "A`n{%-`n  # hidden line one`n  # hidden line two`n-%}`nB"
        $result = Invoke-LiquidTemplate -Template $template -Context @{}
        $result | Should -Be 'AB'
    }
    It 'supports inline comments inside liquid tags' {
        $template = "{% liquid`n# this line is ignored`nassign topic = 'Learning about comments!'`necho topic`n%}"
        $result = Invoke-LiquidTemplate -Template $template -Context @{}
        $result | Should -Be 'Learning about comments!'
    }

    It 'requires block tags opened inside liquid to close inside the same tag' {
        { Invoke-LiquidTemplate -Template "{% liquid`nif true`n  echo 'x'`n%}" -Context @{} } | Should -Throw -ExpectedMessage '*missing endif*'
    }

    It 'expands liquid tags into nested tokens and AST nodes' {
        $ast = ConvertTo-LiquidAst -Template "{% liquid`nassign topic = 'PowerLiquid'`necho topic`n%}" -IncludeTokens
        ($ast.Tokens | Where-Object { $_.Type -eq 'Tag' }).Count | Should -Be 2
        $ast.Nodes[0].Type | Should -Be 'Assign'
        $ast.Nodes[1].Type | Should -Be 'Echo'
    }

    It 'parses AST nodes for case, echo, render, and loop-control tags' {
        $template = "{% case page.kind %}{% when 'note' %}x{% endcase %}{% echo page.kind | upcase %}{% cycle 'odd', 'even' %}{% increment count %}{% decrement count %}"
        $ast = ConvertTo-LiquidAst -Template $template -Dialect JekyllLiquid
        $ast.Nodes[0].Type | Should -Be 'Case'
        $ast.Nodes[1].Type | Should -Be 'Echo'
        $ast.Nodes[2].Type | Should -Be 'Cycle'
        $ast.Nodes[3].Type | Should -Be 'Increment'
        $ast.Nodes[4].Type | Should -Be 'Decrement'
    }

    It 'supports Jekyll-specific URL and serialization filters in the JekyllLiquid dialect' {
        $template = '{{ "/assets/style.css" | relative_url }}|{{ "/assets/style.css" | absolute_url }}|{{ page.data | jsonify }}'
        $context = @{
            site = @{
                url     = 'https://example.com'
                baseurl = '/my-baseurl'
            }
            page = @{
                data = @{
                    title = 'Home'
                }
            }
        }
        $result = Invoke-LiquidTemplate -Template $template -Context $context -Dialect 'JekyllLiquid'
        $result | Should -Be '/my-baseurl/assets/style.css|https://example.com/my-baseurl/assets/style.css|{"title":"Home"}'
    }

    It 'supports custom tags and filters through a registry' {
        $registry = New-LiquidExtensionRegistry
        Register-LiquidTag -Registry $registry -Dialect 'JekyllLiquid' -Name 'seo' -Handler {
            param($Invocation)

            $site = & $Invocation.Helpers.ResolveVariable 'site'
            $page = & $Invocation.Helpers.ResolveVariable 'page'
            return "<title>$($page.title) | $($site.title)</title>"
        }
        Register-LiquidFilter -Registry $registry -Dialect 'JekyllLiquid' -Name 'surround' -Handler {
            param($Invocation)
            return "$($Invocation.Arguments[0])$($Invocation.InputObject)$($Invocation.Arguments[0])"
        }
        $template = '{% seo %} {{ page.title | surround: "[" }}'
        $context = @{
            site = @{
                title = 'Test Site'
            }
            page = @{
                title = 'Home'
            }
        }
        $result = Invoke-LiquidTemplate -Template $template -Context $context -Dialect 'JekyllLiquid' -Registry $registry
        $result | Should -Be '<title>Home | Test Site</title> [Home['
    }

    It 'rejects Jekyll-specific filters in the plain Liquid dialect' {
        {
            Invoke-LiquidTemplate -Template '{{ "/assets/style.css" | relative_url }}' -Context @{ site = @{ baseurl = '/my-baseurl' } }
        } | Should -Throw -ExpectedMessage "*Liquid filter 'relative_url' is not supported in the 'Liquid' dialect.*"
    }
    It 'reports unsupported dialect values' {
        {
            Invoke-LiquidTemplate -Template 'Hello' -Context @{} -Dialect 'Liquid-Next'
        } | Should -Throw -ExpectedMessage "*does not belong to the set*Liquid,JekyllLiquid*"
    }
}
