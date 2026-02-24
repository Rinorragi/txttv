# WAF SQL Injection Tests
# Tests WAF rules against SQL injection attack patterns
# Updated for two-API architecture: Page API + Content API

Describe "WAF SQL Injection Protection" {
    BeforeAll {
        # These tests require a deployed environment
        # Skip if APP_GATEWAY_URL is not set
        $script:appGatewayUrl = $env:APP_GATEWAY_URL
        $script:skipTests = [string]::IsNullOrEmpty($appGatewayUrl)
    }

    Context "SQL Injection on Page API" -Skip:$skipTests {
        $sqlInjectionPatterns = @(
            @{ name = "Basic SELECT"; payload = "'; SELECT * FROM users; --" },
            @{ name = "UNION attack"; payload = "' UNION SELECT username, password FROM users --" },
            @{ name = "DROP TABLE"; payload = "'; DROP TABLE pages; --" },
            @{ name = "Boolean blind"; payload = "' OR '1'='1" },
            @{ name = "Stacked queries"; payload = "'; INSERT INTO admin VALUES('hacker'); --" }
        )

        foreach ($attack in $sqlInjectionPatterns) {
            It "Should block <name> attack on /page/" -TestCases @(@{name = $attack.name; payload = $attack.payload}) {
                $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
                $uri = "$appGatewayUrl/page/100?test=$encodedPayload"
                
                try {
                    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                    $response.StatusCode | Should -BeIn @(403, 400) -Because "SQL injection should be blocked"
                }
                catch {
                    $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
                }
            }
        }
    }

    Context "SQL Injection on Content API" -Skip:$skipTests {
        $sqlInjectionPatterns = @(
            @{ name = "Basic SELECT"; payload = "'; SELECT * FROM users; --" },
            @{ name = "UNION attack"; payload = "' UNION SELECT username, password FROM users --" },
            @{ name = "DROP TABLE"; payload = "'; DROP TABLE pages; --" },
            @{ name = "Boolean blind"; payload = "' OR '1'='1" },
            @{ name = "Stacked queries"; payload = "'; INSERT INTO admin VALUES('hacker'); --" }
        )

        foreach ($attack in $sqlInjectionPatterns) {
            It "Should block <name> attack on /content/" -TestCases @(@{name = $attack.name; payload = $attack.payload}) {
                $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
                $uri = "$appGatewayUrl/content/100?test=$encodedPayload"
                
                try {
                    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                    $response.StatusCode | Should -BeIn @(403, 400) -Because "SQL injection should be blocked on Content API"
                }
                catch {
                    $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
                }
            }
        }

        It "Should block SQL injection in content pageNumber path" {
            $uri = "$appGatewayUrl/content/100' OR 1=1"
            
            try {
                $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                $response.StatusCode | Should -BeIn @(403, 400) -Because "SQL injection in path should be blocked"
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
            }
        }
    }

    Context "Legitimate Requests" -Skip:$skipTests {
        It "Should allow normal page requests" {
            $uri = "$appGatewayUrl/page/100"
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }

        It "Should allow normal content requests" {
            $uri = "$appGatewayUrl/content/100"
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }

        It "Should allow page number input" {
            $uri = "$appGatewayUrl/page/101"
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }

        It "Should allow content page number input" {
            $uri = "$appGatewayUrl/content/101"
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
