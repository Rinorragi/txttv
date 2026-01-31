# WAF XSS Protection Tests
# Tests WAF rules against cross-site scripting attack patterns

Describe "WAF XSS Protection" {
    BeforeAll {
        # These tests require a deployed environment
        # Skip if APP_GATEWAY_URL is not set
        $script:appGatewayUrl = $env:APP_GATEWAY_URL
        $script:skipTests = [string]::IsNullOrEmpty($appGatewayUrl)
    }

    Context "XSS Attack Prevention" -Skip:$skipTests {
        $xssPatterns = @(
            @{ name = "Basic script tag"; payload = "<script>alert('xss')</script>" },
            @{ name = "Event handler"; payload = "<img src=x onerror=alert('xss')>" },
            @{ name = "JavaScript protocol"; payload = "<a href='javascript:alert(1)'>click</a>" },
            @{ name = "SVG onload"; payload = "<svg onload=alert('xss')>" },
            @{ name = "Body onload"; payload = "<body onload=alert('xss')>" },
            @{ name = "Eval function"; payload = "eval(atob('YWxlcnQoMSk='))" }
        )

        foreach ($attack in $xssPatterns) {
            It "Should block <name> attack" -TestCases @(@{name = $attack.name; payload = $attack.payload}) {
                $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
                $uri = "$appGatewayUrl/page/100?input=$encodedPayload"
                
                try {
                    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                    # If we get here, request was allowed - check it's not 200
                    $response.StatusCode | Should -BeIn @(403, 400) -Because "XSS attack should be blocked"
                }
                catch {
                    # 403 Forbidden is expected for WAF blocks
                    $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
                }
            }
        }
    }

    Context "Path-based XSS Prevention" -Skip:$skipTests {
        It "Should block XSS in URL path" {
            $uri = "$appGatewayUrl/page/<script>alert(1)</script>"
            
            try {
                $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction SilentlyContinue
                $response.StatusCode | Should -BeIn @(403, 400)
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -BeIn @(403, 400)
            }
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
