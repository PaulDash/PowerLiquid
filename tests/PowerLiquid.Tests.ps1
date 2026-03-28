Describe 'PowerLiquid module' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $moduleManifestPath = Join-Path -Path $projectRoot -ChildPath 'PowerLiquid.psd1'
        Import-Module $moduleManifestPath -Force

        class DemoTrustedType {
            [int]$Number

            DemoTrustedType([int]$Number) {
                $this.Number = $Number
            }
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

    It 'renders a basic object expression' {
        $result = Invoke-LiquidTemplate -Template 'Hello {{ user.name }}' -Context @{
            user = @{
                name = 'Paul'
            }
        }

        $result | Should -Be 'Hello Paul'
    }

    It 'does not execute script-backed properties from context data' {
        $script:dangerousGetterInvoked = $false
        $user = [pscustomobject]@{
            Name = 'Paul'
        }

        Add-Member -InputObject $user -MemberType ScriptProperty -Name Dangerous -Value {
            $script:dangerousGetterInvoked = $true
            throw 'This getter should never run during template evaluation.'
        }

        $result = Invoke-LiquidTemplate -Template 'Hello {{ user.Dangerous }}' -Context @{
            user = $user
        }

        $result | Should -Be 'Hello '
        $script:dangerousGetterInvoked | Should -BeFalse
    }

    It 'supports host-registered custom tags' {
        $registry = New-LiquidExtensionRegistry

        Register-LiquidTag -Registry $registry -Dialect JekyllLiquid -Name hello -Handler {
            param($Invocation)
            [void]$Invocation
            return 'Hello from a host'
        }

        $result = Invoke-LiquidTemplate -Template '{% hello %}' -Context @{} -Dialect JekyllLiquid -Registry $registry
        $result | Should -Be 'Hello from a host'
    }

    It 'allows explicitly trusted object types to expose their properties' {
        $registry = New-LiquidExtensionRegistry
        Register-LiquidTrustedType -Registry $registry -TypeName DemoTrustedType

        $result = Invoke-LiquidTemplate -Template '{{ event.number }}' -Context @{
            event = [DemoTrustedType]::new(2026)
        } -Registry $registry

        $result | Should -Be '2026'
    }
}

