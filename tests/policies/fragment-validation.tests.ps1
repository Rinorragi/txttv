# Fragment Validation Integration Tests
# Tests policy fragments for APIM compliance and security
# Updated for two-API architecture: page-template + content fragments

# Get repository root (whether running from tests/policies or elsewhere)
if ($PSScriptRoot) {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
} else {
    $repoRoot = (Get-Location).Path
}

# Import validation functions
$validationFunctions = Join-Path $repoRoot "infrastructure/scripts/Validation-Functions.ps1"
if (Test-Path $validationFunctions) {
    . $validationFunctions
}

# Set paths
$fragmentPath = Join-Path $repoRoot "infrastructure/modules/apim/fragments"
$contentSourcePath = Join-Path $repoRoot "content/pages"
$expectedPages = 100..110

# ============================================================================
# Content Fragment Validation (JSON Content API - US1)
# ============================================================================

Describe "Content Fragment Validation" {
    Context "Content Fragment Existence" {
        It "Should have fragments directory" {
            Test-Path $fragmentPath | Should -BeTrue
        }

        It "Should contain all 11 content fragments (100-110)" {
            $fragments = Get-ChildItem -Path $fragmentPath -Filter "content-*.xml"
            $fragments.Count | Should -Be 11
        }

        It "Should have content fragment for page <_>" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            Test-Path $fragmentFile | Should -BeTrue
        }
    }

    Context "Content Fragment XML Well-Formedness" {
        It "Content fragment content-<_>.xml should be valid XML" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $content = Get-Content $fragmentFile -Raw

            {
                $xml = New-Object System.Xml.XmlDocument
                $xml.LoadXml($content)
            } | Should -Not -Throw
        }

        It "Content fragment content-<_>.xml should have <fragment> root element" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw

            $xml.DocumentElement.LocalName | Should -Be "fragment"
        }

        It "Content fragment content-<_>.xml should have <return-response> element" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw

            $returnResponse = $xml.DocumentElement.SelectSingleNode('return-response')
            $returnResponse | Should -Not -BeNullOrEmpty
        }

        It "Content fragment content-<_>.xml should have <set-body> with CDATA" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw

            $setBody = $xml.DocumentElement.SelectSingleNode('return-response/set-body')
            $setBody | Should -Not -BeNullOrEmpty

            $cdataNode = $setBody.FirstChild
            $cdataNode.NodeType | Should -Be ([System.Xml.XmlNodeType]::CDATA)
        }
    }

    Context "Content Fragment Headers" {
        It "Content fragment content-<_>.xml should have Content-Type: application/json" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw

            $headers = $xml.DocumentElement.SelectNodes('return-response/set-header')
            $contentTypeHeader = $headers | Where-Object { $_.name -eq 'Content-Type' }
            $contentTypeHeader | Should -Not -BeNullOrEmpty
            $contentTypeHeader.value | Should -Be 'application/json'
        }

        It "Content fragment content-<_>.xml should have Cache-Control header" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw

            $headers = $xml.DocumentElement.SelectNodes('return-response/set-header')
            $cacheHeader = $headers | Where-Object { $_.name -eq 'Cache-Control' }
            $cacheHeader | Should -Not -BeNullOrEmpty
            $cacheHeader.value | Should -Match 'max-age='
        }

        It "Content fragment content-<_>.xml should have status code 200" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw

            $setStatus = $xml.DocumentElement.SelectSingleNode('return-response/set-status')
            $setStatus | Should -Not -BeNullOrEmpty
            $setStatus.code | Should -Be '200'
        }
    }

    Context "Content Fragment JSON Payload" {
        It "Content fragment content-<_>.xml CDATA should contain valid JSON" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $raw = Get-Content $fragmentFile -Raw
            $match = [regex]::Match($raw, '<!\[CDATA\[([\s\S]*?)\]\]>')
            $match.Success | Should -BeTrue

            $jsonText = $match.Groups[1].Value
            { $jsonText | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Content fragment content-<_>.xml JSON should have required fields" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $raw = Get-Content $fragmentFile -Raw
            $match = [regex]::Match($raw, '<!\[CDATA\[([\s\S]*?)\]\]>')
            $json = $match.Groups[1].Value | ConvertFrom-Json

            $json.pageNumber | Should -Be $_
            $json.title | Should -Not -BeNullOrEmpty
            $json.category | Should -Not -BeNullOrEmpty
            $json.content | Should -Not -BeNullOrEmpty
            $json.navigation | Should -Not -BeNullOrEmpty
        }

        It "Content fragment content-<_>.xml JSON should be byte-identical to source" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $sourceFile = Join-Path $contentSourcePath "page-$_.json"

            if (Test-Path $sourceFile) {
                $raw = Get-Content $fragmentFile -Raw
                $match = [regex]::Match($raw, '<!\[CDATA\[([\s\S]*?)\]\]>')
                $cdataJson = $match.Groups[1].Value

                $sourceJson = Get-Content $sourceFile -Raw
                $cdataJson | Should -Be $sourceJson -Because "CDATA JSON must be byte-identical to source file"
            }
        }
    }

    Context "Content Fragment Size Limits" {
        It "Content fragment content-<_>.xml should be under 256 KB" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $sizeKB = (Get-Item $fragmentFile).Length / 1KB
            $sizeKB | Should -BeLessThan 256 -Because "APIM fragment size limit is 256 KB"
        }

        It "Content fragment content-<_>.xml should be under 2 KB (small JSON)" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $sizeKB = (Get-Item $fragmentFile).Length / 1KB
            $sizeKB | Should -BeLessThan 2 -Because "Content fragments should be minimal JSON wrappers"
        }
    }
}

# ============================================================================
# Page Template Fragment Validation (Page API - US2)
# ============================================================================

Describe "Page Template Fragment Validation" {
    Context "Page Template Existence" {
        It "Should have page-template.xml" {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            Test-Path $templateFile | Should -BeTrue
        }
    }

    Context "Page Template XML Well-Formedness" {
        It "page-template.xml should be valid XML" {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            $content = Get-Content $templateFile -Raw

            {
                $xml = New-Object System.Xml.XmlDocument
                $xml.LoadXml($content)
            } | Should -Not -Throw
        }

        It "page-template.xml should have <fragment> root element" {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            [xml]$xml = Get-Content $templateFile -Raw

            $xml.DocumentElement.LocalName | Should -Be "fragment"
        }

        It "page-template.xml should have <set-body> with CDATA" {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            [xml]$xml = Get-Content $templateFile -Raw

            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $setBody | Should -Not -BeNullOrEmpty

            $cdataNode = $setBody.FirstChild
            $cdataNode.NodeType | Should -Be ([System.Xml.XmlNodeType]::CDATA)
        }
    }

    Context "Page Template HTML Content" {
        BeforeAll {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            [xml]$xml = Get-Content $templateFile -Raw
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $script:htmlContent = $setBody.'#cdata-section'
        }

        It "Should contain valid HTML5 DOCTYPE" {
            $script:htmlContent | Should -Match '<!DOCTYPE\s+html>'
        }

        It "Should have complete HTML structure" {
            $script:htmlContent | Should -Match '<html[^>]*>'
            $script:htmlContent | Should -Match '<head>'
            $script:htmlContent | Should -Match '<body>'
            $script:htmlContent | Should -Match '</html>'
        }

        It "Should have inline CSS" {
            $script:htmlContent | Should -Match '<style>.*</style>'
        }

        It "Should include htmx from CDN" {
            $script:htmlContent | Should -Match 'https://cdn\.jsdelivr\.net/npm/htmx\.org@2\.0\.8'
        }

        It "Should have page-content element for dynamic loading" {
            $script:htmlContent | Should -Match 'id="page-content"'
        }

        It "Should have content-renderer script inlined" {
            $script:htmlContent | Should -Match 'TxtTvContentRenderer'
        }

        It "Should have navigation script inlined" {
            $script:htmlContent | Should -Match '<script>.*</script>'
        }

        It "Should have APIM page number expression in meta tag" {
            $script:htmlContent | Should -Match 'name="page-number"'
            $script:htmlContent | Should -Match 'context\.Variables\.GetValueOrDefault'
        }

        It "Should have navigation links with correct IDs" {
            $script:htmlContent | Should -Match 'id="nav-prev"'
            $script:htmlContent | Should -Match 'id="nav-next"'
        }

        It "Should NOT contain page-specific content" {
            # The template must be shared across all pages
            $script:htmlContent | Should -Not -Match 'PAGE 100|PAGE 101'
            $script:htmlContent | Should -Not -Match 'BREAKING NEWS|TECHNOLOGY'
        }
    }

    Context "Page Template Size" {
        It "page-template.xml should be under 256 KB" {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            $sizeKB = (Get-Item $templateFile).Length / 1KB
            $sizeKB | Should -BeLessThan 256 -Because "APIM fragment size limit is 256 KB"
        }
    }
}

# ============================================================================
# Supporting Fragment Validation (Error Page, Navigation Template)
# ============================================================================

Describe "Supporting Fragment Validation" {
    Context "Error Page Fragment" {
        It "Should have error-page.xml" {
            $errorFile = Join-Path $fragmentPath "error-page.xml"
            Test-Path $errorFile | Should -BeTrue
        }

        It "error-page.xml should be valid XML" {
            $errorFile = Join-Path $fragmentPath "error-page.xml"
            { [xml](Get-Content $errorFile -Raw) } | Should -Not -Throw
        }
    }

    Context "Navigation Template Fragment" {
        It "Should have navigation-template.xml" {
            $navFile = Join-Path $fragmentPath "navigation-template.xml"
            Test-Path $navFile | Should -BeTrue
        }

        It "navigation-template.xml should be valid XML" {
            $navFile = Join-Path $fragmentPath "navigation-template.xml"
            { [xml](Get-Content $navFile -Raw) } | Should -Not -Throw
        }
    }
}

# ============================================================================
# Fragment Count and Naming
# ============================================================================

Describe "Fragment Count and Naming" {
    Context "Fragment Count Limits" {
        It "Should have no more than 100 fragments (APIM limit)" {
            $fragments = Get-ChildItem -Path $fragmentPath -Filter "*.xml" -File
            $fragments.Count | Should -BeLessOrEqual 100 -Because "APIM has a 100 fragment limit"
        }
    }

    Context "Content Fragment Naming Convention" {
        It "Content fragment content-<_>.xml should follow naming convention" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $fileName = (Get-Item $fragmentFile).Name

            $fileName | Should -Match '^content-\d{3}\.xml$' -Because "Filename should be content-NNN.xml"
        }
    }
}

# ============================================================================
# Security Validation
# ============================================================================

Describe "Security Validation" {
    Context "Content Fragment Security" {
        It "Content fragment content-<_>.xml should not have unescaped CDATA terminators" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "content-$_.xml"
            $content = Get-Content $fragmentFile -Raw

            $cdataPattern = '<!\[CDATA\[(.*?)\]\]>'
            if ($content -match $cdataPattern) {
                $cdataContent = $matches[1]

                if ($cdataContent -match '\]\]>') {
                    $cdataContent | Should -Match '\]\]\]\]><!\[CDATA\[>' -Because "]]> must be escaped inside CDATA"
                }
            }
        }
    }

    Context "Page Template Security" {
        BeforeAll {
            $templateFile = Join-Path $fragmentPath "page-template.xml"
            [xml]$xml = Get-Content $templateFile -Raw
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $script:templateHtml = $setBody.'#cdata-section'
        }

        It "page-template.xml should not have inline event handlers" {
            $script:templateHtml | Should -Not -Match '\son\w+\s*=' -Because "Inline event handlers are XSS risks"
        }

        It "page-template.xml should not use eval() or Function()" {
            $script:templateHtml | Should -Not -Match '\beval\s*\(' -Because "eval() is dangerous"
            $script:templateHtml | Should -Not -Match '\bnew\s+Function\s*\(' -Because "Function constructor is dangerous"
        }
    }
}
