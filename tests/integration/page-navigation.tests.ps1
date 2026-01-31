# Page Navigation Integration Tests
# Tests end-to-end page navigation functionality

Describe "Page Navigation Integration" {
    BeforeAll {
        # These tests require a deployed environment
        # Skip if APP_GATEWAY_URL is not set
        $script:appGatewayUrl = $env:APP_GATEWAY_URL
        $script:skipTests = [string]::IsNullOrEmpty($appGatewayUrl)
    }

    Context "Basic Page Access" -Skip:$skipTests {
        It "Should return 200 for page 100" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }

        It "Should return HTML content type" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Headers['Content-Type'] | Should -Match "text/html"
        }

        It "Should include correlation ID header" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Headers['X-Correlation-ID'] | Should -Not -BeNullOrEmpty
        }

        It "Should include cache control header" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Headers['Cache-Control'] | Should -Match "max-age=300"
        }
    }

    Context "Page Content Validation" -Skip:$skipTests {
        It "Should display page 100 with breaking news content" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Content | Should -Match "BREAKING NEWS"
            $response.Content | Should -Match "PAGE 100"
        }

        It "Should display page 101 with technology news" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/101" -UseBasicParsing
            $response.Content | Should -Match "TECHNOLOGY"
        }

        It "Should include navigation controls" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Content | Should -Match "hx-get"
            $response.Content | Should -Match "Previous"
            $response.Content | Should -Match "Next"
        }

        It "Should include HTMX script" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Content | Should -Match "htmx.org"
        }
    }

    Context "Navigation Between Pages" -Skip:$skipTests {
        It "Should navigate from page 100 to page 101" {
            $response100 = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response101 = Invoke-WebRequest -Uri "$appGatewayUrl/page/101" -UseBasicParsing
            
            $response100.Content | Should -Match "PAGE 100"
            $response101.Content | Should -Match "PAGE 101"
        }

        It "Should have different content on different pages" {
            $response100 = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response101 = Invoke-WebRequest -Uri "$appGatewayUrl/page/101" -UseBasicParsing
            
            $response100.Content | Should -Not -Be $response101.Content
        }
    }

    Context "Error Handling" -Skip:$skipTests {
        It "Should show error page for non-existent page" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/500" -UseBasicParsing
            $response.StatusCode | Should -Be 200  # Returns 200 with error page HTML
            $response.Content | Should -Match "PAGE NOT FOUND|Error|not exist"
        }

        It "Should return 400 for invalid page number" {
            try {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/abc" -UseBasicParsing -ErrorAction Stop
                $response.StatusCode | Should -Be 400
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 400
            }
        }

        It "Should return 400 for page number below 100" {
            try {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/99" -UseBasicParsing -ErrorAction Stop
                $response.StatusCode | Should -Be 400
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 400
            }
        }

        It "Should return 400 for page number above 999" {
            try {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/1000" -UseBasicParsing -ErrorAction Stop
                $response.StatusCode | Should -Be 400
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 400
            }
        }
    }

    Context "Home Page Redirect" -Skip:$skipTests {
        It "Should redirect from / to /page/100" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/" -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
            $response.StatusCode | Should -Be 302
            $response.Headers['Location'] | Should -Match "/page/100"
        }
    }
}

Describe "Page Navigation Local Validation" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $fragmentsPath = Join-Path $repoRoot "infrastructure/modules/apim/fragments"
        $contentPath = Join-Path $repoRoot "content/pages"
    }

    It "Should have matching content files and fragments" {
        $contentFiles = Get-ChildItem -Path $contentPath -Filter "page-*.txt" -ErrorAction SilentlyContinue
        $fragmentFiles = Get-ChildItem -Path $fragmentsPath -Filter "page-*.xml" -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -notmatch "error|navigation" }
        
        $contentFiles.Count | Should -Be $fragmentFiles.Count -Because "Each content file should have a corresponding fragment"
    }

    It "Should have navigation links pointing to valid pages" {
        $fragmentFiles = Get-ChildItem -Path $fragmentsPath -Filter "page-*.xml" -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -notmatch "error|navigation" }
        
        foreach ($fragment in $fragmentFiles) {
            $content = Get-Content $fragment.FullName -Raw
            # Extract page number from filename
            $pageNum = [regex]::Match($fragment.Name, 'page-(\d+)').Groups[1].Value
            $prevPage = [int]$pageNum - 1
            $nextPage = [int]$pageNum + 1
            
            # Check that previous and next page links exist
            $content | Should -Match "hx-get=`"/page/$nextPage`"" -Because "Should have next page link"
        }
    }
}
