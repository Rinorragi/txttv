# Page Navigation Integration Tests
# Tests end-to-end page navigation functionality
# Updated for two-API architecture: Page API (HTML) + Content API (JSON)

Describe "Page API Integration" {
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
            $response.Headers['Cache-Control'] | Should -Match "max-age="
        }
    }

    Context "Shared Page Template (US2)" -Skip:$skipTests {
        It "Should return the same HTML template for all pages" {
            $response100 = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response101 = Invoke-WebRequest -Uri "$appGatewayUrl/page/101" -UseBasicParsing

            # The HTML shell should be identical (content loaded via fetch)
            # But the page-number meta tag will differ
            $response100.Content | Should -Match 'id="page-content"' -Because "Should have dynamic content container"
            $response101.Content | Should -Match 'id="page-content"' -Because "Should have dynamic content container"
        }

        It "Should include content-renderer script" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Content | Should -Match 'TxtTvContentRenderer' -Because "Should have content renderer for fetch-based loading"
        }

        It "Should include HTMX script" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Content | Should -Match "htmx.org"
        }

        It "Should have navigation link elements" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/100" -UseBasicParsing
            $response.Content | Should -Match 'id="nav-prev"' -Because "Should have previous navigation link"
            $response.Content | Should -Match 'id="nav-next"' -Because "Should have next navigation link"
        }
    }

    Context "Error Handling" -Skip:$skipTests {
        It "Should handle non-existent page gracefully" {
            # The page template loads for any valid 3-digit number
            # Content 404 is handled by client-side content-renderer.js
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/page/500" -UseBasicParsing
            $response.StatusCode | Should -BeIn @(200, 404) -Because "May return template (200) or not-found (404)"
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

Describe "Content API Integration" {
    BeforeAll {
        $script:appGatewayUrl = $env:APP_GATEWAY_URL
        $script:skipTests = [string]::IsNullOrEmpty($appGatewayUrl)
    }

    Context "Content API Access" -Skip:$skipTests {
        It "Should return 200 for content/100" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/100" -UseBasicParsing
            $response.StatusCode | Should -Be 200
        }

        It "Should return JSON content type" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/100" -UseBasicParsing
            $response.Headers['Content-Type'] | Should -Match "application/json"
        }

        It "Should return valid JSON with required fields" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/100" -UseBasicParsing
            $json = $response.Content | ConvertFrom-Json

            $json.pageNumber | Should -Be 100
            $json.title | Should -Not -BeNullOrEmpty
            $json.category | Should -Not -BeNullOrEmpty
            $json.content | Should -Not -BeNullOrEmpty
            $json.navigation | Should -Not -BeNullOrEmpty
        }

        It "Should return cache control header" {
            $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/100" -UseBasicParsing
            $response.Headers['Cache-Control'] | Should -Match "max-age="
        }
    }

    Context "Content API for All Pages" -Skip:$skipTests {
        foreach ($page in 100..110) {
            It "Should return valid JSON for content/$page" -TestCases @(@{pageNum = $page}) {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/$pageNum" -UseBasicParsing
                $response.StatusCode | Should -Be 200

                $json = $response.Content | ConvertFrom-Json
                $json.pageNumber | Should -Be $pageNum
            }
        }
    }

    Context "Content API Navigation Chain" -Skip:$skipTests {
        It "Should have correct prev/next chain across pages 100-110" {
            $prevPage = $null
            foreach ($page in 100..110) {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/$page" -UseBasicParsing
                $json = $response.Content | ConvertFrom-Json

                if ($page -eq 100) {
                    $json.navigation.prev | Should -BeNullOrEmpty -Because "Page 100 should have no previous"
                } else {
                    $json.navigation.prev | Should -Be $prevPage -Because "Page $page prev should be $prevPage"
                }

                if ($page -eq 110) {
                    $json.navigation.next | Should -BeNullOrEmpty -Because "Page 110 should have no next"
                } else {
                    $json.navigation.next | Should -Be ($page + 1) -Because "Page $page next should be $($page + 1)"
                }

                $prevPage = $page
            }
        }
    }

    Context "Content API Error Handling" -Skip:$skipTests {
        It "Should return 404 for non-existent content page" {
            try {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/999" -UseBasicParsing -ErrorAction Stop
                $response.StatusCode | Should -Be 404
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 404
            }
        }

        It "Should return 400 for invalid content page number" {
            try {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/abc" -UseBasicParsing -ErrorAction Stop
                $response.StatusCode | Should -Be 400
            }
            catch {
                $_.Exception.Response.StatusCode.value__ | Should -Be 400
            }
        }

        It "404 response should be JSON with error field" {
            try {
                $response = Invoke-WebRequest -Uri "$appGatewayUrl/content/999" -UseBasicParsing -ErrorAction Stop
            }
            catch {
                $errorBody = $_.ErrorDetails.Message
                if ($errorBody) {
                    $json = $errorBody | ConvertFrom-Json
                    $json.error | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
}

Describe "Two-API Architecture Local Validation" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $fragmentsPath = Join-Path $repoRoot "infrastructure/modules/apim/fragments"
        $contentPath = Join-Path $repoRoot "content/pages"
    }

    It "Should have matching JSON content files and content fragments" {
        $contentFiles = Get-ChildItem -Path $contentPath -Filter "page-*.json" -ErrorAction SilentlyContinue
        $contentFragments = Get-ChildItem -Path $fragmentsPath -Filter "content-*.xml" -ErrorAction SilentlyContinue

        $contentFiles.Count | Should -Be $contentFragments.Count -Because "Each JSON content file should have a corresponding content fragment"
    }

    It "Should have a shared page-template fragment" {
        $templateFile = Join-Path $fragmentsPath "page-template.xml"
        Test-Path $templateFile | Should -BeTrue -Because "Two-API architecture uses a single shared page template"
    }

    It "Content fragments should have JSON payloads matching source files" {
        $contentFiles = Get-ChildItem -Path $contentPath -Filter "page-*.json" -ErrorAction SilentlyContinue
        foreach ($file in $contentFiles) {
            $pageNum = [regex]::Match($file.Name, 'page-(\d+)').Groups[1].Value
            $fragmentFile = Join-Path $fragmentsPath "content-$pageNum.xml"

            if (Test-Path $fragmentFile) {
                $raw = Get-Content $fragmentFile -Raw
                $match = [regex]::Match($raw, '<!\[CDATA\[([\s\S]*?)\]\]>')
                $cdataJson = $match.Groups[1].Value

                $sourceJson = Get-Content $file.FullName -Raw
                $cdataJson | Should -Be $sourceJson -Because "Content fragment content-$pageNum.xml JSON must match source $($file.Name)"
            }
        }
    }

    It "Navigation links should point to valid pages" {
        $contentFiles = Get-ChildItem -Path $contentPath -Filter "page-*.json" -ErrorAction SilentlyContinue
        $validPages = $contentFiles | ForEach-Object {
            [regex]::Match($_.Name, 'page-(\d+)').Groups[1].Value
        }

        foreach ($file in $contentFiles) {
            $json = Get-Content $file.FullName -Raw | ConvertFrom-Json

            if ($json.navigation.prev) {
                $json.navigation.prev.ToString() | Should -BeIn $validPages -Because "$($file.Name) prev link should point to valid page"
            }
            if ($json.navigation.next) {
                $json.navigation.next.ToString() | Should -BeIn $validPages -Because "$($file.Name) next link should point to valid page"
            }
            if ($json.navigation.related) {
                foreach ($related in $json.navigation.related) {
                    $related.ToString() | Should -BeIn $validPages -Because "$($file.Name) related link should point to valid page"
                }
            }
        }
    }
}
