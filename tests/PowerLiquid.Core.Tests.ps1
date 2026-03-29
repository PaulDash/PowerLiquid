Describe 'PowerLiquid core behavior' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force

        class DemoTrustedType {
            [int]$Number
            DemoTrustedType([int]$Number) { $this.Number = $Number }
        }
    }

    It 'exports the expected public commands' {
        (Get-Command Invoke-LiquidTemplate -ErrorAction Stop).Name | Should -Be 'Invoke-LiquidTemplate'
        (Get-Command ConvertTo-LiquidAst -ErrorAction Stop).Name | Should -Be 'ConvertTo-LiquidAst'
        (Get-Command New-LiquidExtensionRegistry -ErrorAction Stop).Name | Should -Be 'New-LiquidExtensionRegistry'
        (Get-Command Register-LiquidTag -ErrorAction Stop).Name | Should -Be 'Register-LiquidTag'
        (Get-Command Register-LiquidFilter -ErrorAction Stop).Name | Should -Be 'Register-LiquidFilter'
        (Get-Command Register-LiquidTrustedType -ErrorAction Stop).Name | Should -Be 'Register-LiquidTrustedType'
    }

    It 'parses templates into a documented AST root object' {
        $ast = ConvertTo-LiquidAst -Template '{% if page.title %}{{ page.title }}{% endif %}' -Dialect JekyllLiquid -IncludeTokens
        $ast.PSTypeNames | Should -Contain 'PowerLiquid.Ast'
        $ast.Dialect | Should -Be 'JekyllLiquid'
        $ast.Nodes.Count | Should -Be 1
        $ast.Nodes[0].Type | Should -Be 'If'
        $ast.Tokens.Count | Should -BeGreaterThan 0
    }

    It 'preserves line and column locations on AST nodes and tokens' {
        $template = [string]::Join([Environment]::NewLine, @('{% if page.title %}','  {{ page.title }}','{% endif %}'))
        $ast = ConvertTo-LiquidAst -Template $template -Dialect JekyllLiquid -IncludeTokens
        $outputToken = $ast.Tokens | Where-Object { $_.Type -eq 'Output' } | Select-Object -First 1
        $ast.Nodes[0].Location.StartLine | Should -Be 1
        $ast.Nodes[0].Location.StartColumn | Should -Be 1
        $ast.Nodes[0].Location.EndLine | Should -Be 3
        $ast.Tokens[0].Location.StartLine | Should -Be 1
        $outputToken.Location.StartLine | Should -Be 2
        $outputToken.Location.StartColumn | Should -Be 3
    }

    It 'renders a basic object expression' {
        $result = Invoke-LiquidTemplate -Template 'Hello {{ user.name }}' -Context @{ user = @{ name = 'Paul' } }
        $result | Should -Be 'Hello Paul'
    }

    It 'does not execute script-backed properties from context data' {
        $script:dangerousGetterInvoked = $false
        $user = [pscustomobject]@{ Name = 'Paul' }
        Add-Member -InputObject $user -MemberType ScriptProperty -Name Dangerous -Value { $script:dangerousGetterInvoked = $true; throw 'This getter should never run during template evaluation.' }
        $result = Invoke-LiquidTemplate -Template 'Hello {{ user.Dangerous }}' -Context @{ user = $user }
        $result | Should -Be 'Hello '
        $script:dangerousGetterInvoked | Should -BeFalse
    }

    It 'supports host-registered custom tags' {
        $registry = New-LiquidExtensionRegistry
        Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name hello -Handler { param($Invocation) [void]$Invocation; 'Hello from a host' }
        $result = Invoke-LiquidTemplate -Template '{% hello %}' -Context @{} -Dialect JekyllLiquid -Registry $registry
        $result | Should -Be 'Hello from a host'
    }

    It 'allows explicitly trusted object types to expose their properties' {
        $registry = New-LiquidExtensionRegistry
        Register-LiquidTrustedType -Registry $registry -TypeName DemoTrustedType
        $result = Invoke-LiquidTemplate -Template '{{ event.number }}' -Context @{ event = [DemoTrustedType]::new(2026) } -Registry $registry
        $result | Should -Be '2026'
    }

    It 'supports include_relative beneath the configured relative root' {
        $templateRoot = Join-Path -Path $TestDrive -ChildPath 'relative-include-root'
        $postsRoot = Join-Path -Path $templateRoot -ChildPath '_posts'
        $postPath = Join-Path -Path $postsRoot -ChildPath '2026-03-29-example.md'
        $snippetDirectory = Join-Path -Path $postsRoot -ChildPath 'snippets'
        $snippetPath = Join-Path -Path $snippetDirectory -ChildPath 'card.txt'
        [void](New-Item -Path $snippetDirectory -ItemType Directory -Force)
        Set-Content -LiteralPath $postPath -Encoding UTF8 -Value '{% include_relative snippets/card.txt %}'
        Set-Content -LiteralPath $snippetPath -Encoding UTF8 -Value 'Relative include content'
        $result = Invoke-LiquidTemplate -Template (Get-Content -LiteralPath $postPath -Raw) -Context @{} -Dialect JekyllLiquid -CurrentFilePath $postPath -RelativeIncludeRoot $postsRoot
        $result.Trim() | Should -Be 'Relative include content'
    }

    It 'rejects include_relative paths that escape the configured relative root' {
        $templateRoot = Join-Path -Path $TestDrive -ChildPath 'relative-include-escape-root'
        $postsRoot = Join-Path -Path $templateRoot -ChildPath '_posts'
        $postPath = Join-Path -Path $postsRoot -ChildPath '2026-03-29-example.md'
        $outsidePath = Join-Path -Path $templateRoot -ChildPath 'outside.txt'
        [void](New-Item -Path $postsRoot -ItemType Directory -Force)
        Set-Content -LiteralPath $postPath -Encoding UTF8 -Value '{% include_relative ../outside.txt %}'
        Set-Content -LiteralPath $outsidePath -Encoding UTF8 -Value 'Outside'
        { Invoke-LiquidTemplate -Template (Get-Content -LiteralPath $postPath -Raw) -Context @{} -Dialect JekyllLiquid -CurrentFilePath $postPath -RelativeIncludeRoot $postsRoot } | Should -Throw -ExpectedMessage '*include_relative*outside the allowed relative include root*'
    }

    It 'warns and ignores include in the Liquid dialect' {
        $includeRoot = Join-Path -Path $TestDrive -ChildPath 'liquid-include-root'
        $includePath = Join-Path -Path $includeRoot -ChildPath 'card.txt'
        [void](New-Item -Path $includeRoot -ItemType Directory -Force)
        Set-Content -LiteralPath $includePath -Encoding UTF8 -Value 'Included content'
        $stream = & { Invoke-LiquidTemplate -Template '{% include card.txt %}X' -Context @{} -Dialect Liquid -IncludeRoot $includeRoot } 3>&1
        ($stream | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Count | Should -Be 1
        ($stream | Where-Object { $_ -is [string] } | Select-Object -Last 1) | Should -Be 'X'
    }

    It 'still supports include in the JekyllLiquid dialect' {
        $includeRoot = Join-Path -Path $TestDrive -ChildPath 'jekyll-include-root'
        $includePath = Join-Path -Path $includeRoot -ChildPath 'card.txt'
        [void](New-Item -Path $includeRoot -ItemType Directory -Force)
        Set-Content -LiteralPath $includePath -Encoding UTF8 -Value 'Included content'
        (Invoke-LiquidTemplate -Template '{% include card.txt %}' -Context @{} -Dialect JekyllLiquid -IncludeRoot $includeRoot).Trim() | Should -Be 'Included content'
    }

    It 'wraps parse failures from ConvertTo-LiquidAst with command context' {
        { ConvertTo-LiquidAst -Template '{% if page.title %}x' } | Should -Throw -ExpectedMessage 'ConvertTo-LiquidAst failed:*missing endif*'
    }

    It 'wraps render failures from Invoke-LiquidTemplate with command context' {
        { Invoke-LiquidTemplate -Template '{% break %}' -Context @{} } | Should -Throw -ExpectedMessage 'Invoke-LiquidTemplate failed:*break tag can only be used inside for or tablerow loops*'
    }
}