# WAF SQL Injection Tests
# Tests WAF rules against SQL injection attack patterns

Describe "WAF SQL Injection Protection" {
    BeforeAll {
        # These tests require a deployed environment
        # Skip if APP_GATEWAY_URL is not set
        $script:appGatewayUrl = $env:APP_GATEWAY_URL
        $script:skipTests = [string]::IsNullOrEmpty($appGatewayUrl)
    }

    Context "SQL Injection Attack Prevention" -Skip:$skipTests {
        $sqlInjectionPatterns = @(
            @{ name = "Basic SELECT"; payload = "'; SELECT * FROM users; --" },
            @{ name = "UNION attack"; payload = "' UNION SELECT username, password FROM users --" },
            @{ name = "DROP TABLE"; payload = "'; DROP TABLE pages; --" },
            @{ name = "Boolean blind"; payload = "' OR '1'='1" },
            @{ name = "Stacked queries"; payload = "'; INSERT INTO admin VALUES('hacker'); --" }
        )

        foreach ($attack in $sqlInjectionPatterns) {
            It "Should block <name> attack" -TestCases @(@{name = $attack.name; payload = $attack.payload}) {
                $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
                $uri = "$appGatewayUrl/page/100?test=$encodedPayload"
                
                try {
                    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                    # If we get here, request was allowed - check it's not 200
                    $response.StatusCode | Should -BeIn @(403, 400) -Because "SQL injection should be blocked"
                }
                catch {
                    # 403 Forbidden is expected for WAF blocks
                    $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
                }
            }
        }
    }

    Context "Legitimate Requests" -Skip:$skipTests {
        It "Should allow normal page requests" {
            $uri = "$appGatewayUrl/page/100"
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }

        It "Should allow page number input" {
            $uri = "$appGatewayUrl/page/101"
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }
    }
}

Describe "WAF SQL Injection Rule Configuration" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $wafRulePath = Join-Path $repoRoot "infrastructure/modules/waf/rules/sql-injection.bicep"
    }

    It "Should have SQL injection rule file" {
        Test-Path $wafRulePath | Should -Be $true
    }

    It "Should contain common SQL keywords" {
        $content = Get-Content $wafRulePath -Raw
        $content | Should -Match "select"
        $content | Should -Match "insert"
        $content | Should -Match "delete"
        $content | Should -Match "drop"
        $content | Should -Match "union"
    }

    It "Should use appropriate transforms" {
        $content = Get-Content $wafRulePath -Raw
        $content | Should -Match "Lowercase"
        $content | Should -Match "UrlDecode"
    }
}
