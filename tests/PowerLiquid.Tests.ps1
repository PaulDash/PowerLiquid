Describe 'PowerLiquid module' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force
    }

    It 'exports the expected public commands' {
        (Get-Command Invoke-LiquidTemplate -ErrorAction Stop).Name | Should -Be 'Invoke-LiquidTemplate'
        (Get-Command ConvertTo-LiquidAst -ErrorAction Stop).Name | Should -Be 'ConvertTo-LiquidAst'
        (Get-Command New-LiquidExtensionRegistry -ErrorAction Stop).Name | Should -Be 'New-LiquidExtensionRegistry'
        (Get-Command Register-LiquidTag -ErrorAction Stop).Name | Should -Be 'Register-LiquidTag'
        (Get-Command Register-LiquidFilter -ErrorAction Stop).Name | Should -Be 'Register-LiquidFilter'
    }

    It 'parses templates into a documented AST root object' {
        $ast = ConvertTo-LiquidAst -Template '{% if page.title %}{{ page.title }}{% endif %}' -Dialect JekyllLiquid -IncludeTokens

        $ast.PSTypeNames | Should -Contain 'PowerLiquid.Ast'
        $ast.Dialect | Should -Be 'JekyllLiquid'
        $ast.Nodes.Count | Should -Be 1
        $ast.Nodes[0].Type | Should -Be 'If'
        $ast.Tokens.Count | Should -BeGreaterThan 0
    }

    It 'renders a basic object expression' {
        $result = Invoke-LiquidTemplate -Template 'Hello {{ user.name }}' -Context @{
            user = @{
                name = 'Paul'
            }
        }

        $result | Should -Be 'Hello Paul'
    }

    It 'supports host-registered custom tags' {
        $registry = New-LiquidExtensionRegistry

        Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name hello -Handler {
            param($Invocation)
            return 'Hello from a host'
        }

        $result = Invoke-LiquidTemplate -Template '{% hello %}' -Context @{} -Dialect JekyllLiquid -Registry $registry
        $result | Should -Be 'Hello from a host'
    }
}
