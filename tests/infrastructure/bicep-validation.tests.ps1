# Bicep Validation Tests
# Validates Bicep templates for syntax and linting issues

Describe "Bicep Infrastructure Validation" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $modulesPath = Join-Path $repoRoot "infrastructure/modules"
        $environmentsPath = Join-Path $repoRoot "infrastructure/environments"
    }

    Context "Module Validation" {
        $modules = @(
            "storage/main.bicep",
            "backend/main.bicep",
            "apim/main.bicep",
            "app-gateway/main.bicep",
            "waf/main.bicep"
        )

        foreach ($module in $modules) {
            It "Should validate <module>" -TestCases @(@{module = $module}) {
                $modulePath = Join-Path $modulesPath $module
                { az bicep build --file $modulePath --stdout 2>&1 } | Should -Not -Throw
            }
        }
    }

    Context "Environment Validation" {
        $environments = @("dev", "staging", "prod")

        foreach ($env in $environments) {
            It "Should validate <env> environment" -TestCases @(@{env = $env}) {
                $envPath = Join-Path $environmentsPath "$env/main.bicep"
                if (Test-Path $envPath) {
                    { az bicep build --file $envPath --stdout 2>&1 } | Should -Not -Throw
                }
            }
        }
    }

    Context "Bicep Linting" {
        It "Should have no high-severity linting errors in storage module" {
            $modulePath = Join-Path $modulesPath "storage/main.bicep"
            $lintOutput = az bicep lint --file $modulePath 2>&1
            $lintOutput | Should -Not -Match "Error"
        }

        It "Should have no high-severity linting errors in apim module" {
            $modulePath = Join-Path $modulesPath "apim/main.bicep"
            $lintOutput = az bicep lint --file $modulePath 2>&1
            $lintOutput | Should -Not -Match "Error"
        }
    }
}

Describe "WAF Rules Validation" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $wafRulesPath = Join-Path $repoRoot "infrastructure/modules/waf/rules"
    }

    It "Should have rate limiting rule defined" {
        $rulePath = Join-Path $wafRulesPath "rate-limiting.bicep"
        Test-Path $rulePath | Should -Be $true
    }

    It "Should have SQL injection rule defined" {
        $rulePath = Join-Path $wafRulesPath "sql-injection.bicep"
        Test-Path $rulePath | Should -Be $true
    }

    It "Should have XSS protection rule defined" {
        $rulePath = Join-Path $wafRulesPath "xss-protection.bicep"
        Test-Path $rulePath | Should -Be $true
    }
}
