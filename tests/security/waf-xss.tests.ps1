# WAF XSS Protection Tests
# Tests WAF rules against cross-site scripting attack patterns
# Updated for two-API architecture: Page API + Content API

Describe "WAF XSS Protection" {
    BeforeAll {
        # These tests require a deployed environment
        # Skip if APP_GATEWAY_URL is not set
        $script:appGatewayUrl = $env:APP_GATEWAY_URL
        $script:skipTests = [string]::IsNullOrEmpty($appGatewayUrl)
    }

    Context "XSS Attack Prevention on Page API" -Skip:$skipTests {
        $xssPatterns = @(
            @{ name = "Basic script tag"; payload = "<script>alert('xss')</script>" },
            @{ name = "Event handler"; payload = "<img src=x onerror=alert('xss')>" },
            @{ name = "JavaScript protocol"; payload = "<a href='javascript:alert(1)'>click</a>" },
            @{ name = "SVG onload"; payload = "<svg onload=alert('xss')>" },
            @{ name = "Body onload"; payload = "<body onload=alert('xss')>" },
            @{ name = "Eval function"; payload = "eval(atob('YWxlcnQoMSk='))" }
        )

        foreach ($attack in $xssPatterns) {
            It "Should block <name> attack on /page/" -TestCases @(@{name = $attack.name; payload = $attack.payload}) {
                $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
                $uri = "$appGatewayUrl/page/100?input=$encodedPayload"
                
                try {
                    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                    $response.StatusCode | Should -BeIn @(403, 400) -Because "XSS attack should be blocked"
                }
                catch {
                    $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
                }
            }
        }
    }

    Context "XSS Attack Prevention on Content API" -Skip:$skipTests {
        $xssPatterns = @(
            @{ name = "Basic script tag"; payload = "<script>alert('xss')</script>" },
            @{ name = "Event handler"; payload = "<img src=x onerror=alert('xss')>" },
            @{ name = "JavaScript protocol"; payload = "<a href='javascript:alert(1)'>click</a>" },
            @{ name = "SVG onload"; payload = "<svg onload=alert('xss')>" },
            @{ name = "Eval function"; payload = "eval(atob('YWxlcnQoMSk='))" }
        )

        foreach ($attack in $xssPatterns) {
            It "Should block <name> attack on /content/" -TestCases @(@{name = $attack.name; payload = $attack.payload}) {
                $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
                $uri = "$appGatewayUrl/content/100?input=$encodedPayload"
                
                try {
                    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                    $response.StatusCode | Should -BeIn @(403, 400) -Because "XSS attack should be blocked on Content API"
                }
                catch {
                    $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
                }
            }
        }
    }

    Context "Path-based XSS Prevention" -Skip:$skipTests {
        It "Should block XSS in page URL path" {
            $uri = "$appGatewayUrl/page/<script>alert(1)</script>"
            
            try {
                $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                $response.StatusCode | Should -BeIn @(403, 400)
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
            }
        }

        It "Should block XSS in content URL path" {
            $uri = "$appGatewayUrl/content/<script>alert(1)</script>"
            
            try {
                $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                $response.StatusCode | Should -BeIn @(403, 400)
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
    }
}

Describe "WAF XSS Rule Configuration" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $wafRulePath = Join-Path $repoRoot "infrastructure/modules/waf/rules/xss-protection.bicep"
    }

    It "Should have XSS protection rule file" {
        Test-Path $wafRulePath | Should -Be $true
    }

    It "Should contain script tag patterns" {
        $content = Get-Content $wafRulePath -Raw
        $content | Should -Match "<script"
    }

    It "Should contain event handler patterns" {
        $content = Get-Content $wafRulePath -Raw
        $content | Should -Match "onerror="
        $content | Should -Match "onload="
    }

    It "Should contain JavaScript protocol pattern" {
        $content = Get-Content $wafRulePath -Raw
        $content | Should -Match "javascript:"
    }

    It "Should use HTML entity decode transform" {
        $content = Get-Content $wafRulePath -Raw
        $content | Should -Match "HtmlEntityDecode"
    }
}
