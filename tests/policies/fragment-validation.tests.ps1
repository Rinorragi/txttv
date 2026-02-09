# Fragment Validation Integration Tests
# Tests policy fragments for APIM compliance and security

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

# Set fragment path
$fragmentPath = Join-Path $repoRoot "infrastructure/modules/apim/fragments"
$expectedPages = 100..110

Describe "Policy Fragment Validation" {
    Context "Fragment Existence" {
        It "Should have fragments directory" {
            Test-Path $fragmentPath | Should -BeTrue
        }
        
        It "Should contain all 11 page fragments (100-110)" {
            $fragments = Get-ChildItem -Path $fragmentPath -Filter "page-*.xml"
            $fragments.Count | Should -Be 11
        }
        
        It "Should have fragment for page <_>" -TestCases @(
            @{Page = 100}, @{Page = 101}, @{Page = 102}, @{Page = 103},
            @{Page = 104}, @{Page = 105}, @{Page = 106}, @{Page = 107},
            @{Page = 108}, @{Page = 109}, @{Page = 110}
        ) {
            param($Page)
            $fragmentFile = Join-Path $fragmentPath "page-$Page.xml"
            Test-Path $fragmentFile | Should -BeTrue
        }
    }
    
    Context "Fragment File Properties" {
        It "Fragment page-<Page>.xml should have UTF-8 BOM encoding" -TestCases @(
            @{Page = 100}, @{Page = 101}, @{Page = 102}, @{Page = 103},
            @{Page = 104}, @{Page = 105}, @{Page = 106}, @{Page = 107},
            @{Page = 108}, @{Page = 109}, @{Page = 110}
        ) {
            param($Page)
            $fragmentFile = Join-Path $fragmentPath "page-$Page.xml"
            $bytes = [System.IO.File]::ReadAllBytes($fragmentFile)
            
            # Check for UTF-8 BOM (EF BB BF)
            if ($bytes.Length -ge 3) {
                $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
                $hasBOM | Should -BeTrue -Because "APIM requires UTF-8 BOM encoding"
            }
        }
        
        It "Fragment page-<Page>.xml should be under 256 KB" -TestCases @(
            @{Page = 100}, @{Page = 101}, @{Page = 102}, @{Page = 103},
            @{Page = 104}, @{Page = 105}, @{Page = 106}, @{Page = 107},
            @{Page = 108}, @{Page = 109}, @{Page = 110}
        ) {
            param($Page)
            $fragmentFile = Join-Path $fragmentPath "page-$Page.xml"
            $sizeKB = (Get-Item $fragmentFile).Length / 1KB
            $sizeKB | Should -BeLessThan 256 -Because "APIM fragment size limit is 256 KB"
        }
    }
    
    Context "XML Well-Formedness" {
        It "Fragment page-<_>.xml should be valid XML" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            $content = Get-Content $fragmentFile -Raw
            
            { 
                $xml = New-Object System.Xml.XmlDocument
                $xml.LoadXml($content)
            } | Should -Not -Throw
        }
        
        It "Fragment page-<_>.xml should have <fragment> root element" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $xml.DocumentElement.LocalName | Should -Be "fragment"
        }
        
        It "Fragment page-<_>.xml should have <set-body> element" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $setBody | Should -Not -BeNullOrEmpty
        }
        
        It "Fragment page-<_>.xml should have HTML in CDATA section" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $cdataNode = $setBody.FirstChild
            
            $cdataNode.NodeType | Should -Be ([System.Xml.XmlNodeType]::CDATA)
        }
    }
    
    Context "HTML Content Validation" {
        It "Fragment page-<_>.xml should contain valid HTML5 DOCTYPE" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match '<!DOCTYPE\s+html>'
        }
        
        It "Fragment page-<_>.xml should have complete HTML structure" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match '<html[^>]*>'
            $htmlContent | Should -Match '<head>'
            $htmlContent | Should -Match '<body>'
            $htmlContent | Should -Match '</html>'
        }
        
        It "Fragment page-<_>.xml should include page number in content" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match $_ -Because "Page number should appear in the content"
        }
        
        It "Fragment page-<_>.xml should have navigation links" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match 'Previous' -Because "Should have previous link"
            $htmlContent | Should -Match 'Next' -Because "Should have next link"
            $htmlContent | Should -Match 'Index' -Because "Should have index link"
        }
    }
    
    Context "CSS and JavaScript Inclusion" {
        It "Fragment page-<_>.xml should have inline CSS" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match '<style>.*</style>' -Because "CSS should be inlined"
        }
        
        It "Fragment page-<_>.xml should include htmx from CDN" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match 'https://cdn\.jsdelivr\.net/npm/htmx\.org@2\.0\.8' -Because "htmx 2.0.8 should be loaded from CDN per constitution v1.2.2"
        }
        
        It "Fragment page-<_>.xml should have navigation script" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Match '<script>.*</script>' -Because "Navigation script should be included"
        }
    }
    
    Context "Fragment ID Naming Convention" {
        It "Fragment page-<_>.xml should follow naming convention" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            $fileName = (Get-Item $fragmentFile).Name
            
            $fileName | Should -Match '^page-\d{3}\.xml$' -Because "Filename should be page-NNN.xml"
        }
    }
    
    Context "Fragment Count Limits" {
        It "Should have no more than 100 fragments (APIM limit)" {
            $fragments = Get-ChildItem -Path $fragmentPath -Filter "*.xml" -File
            $fragments.Count | Should -BeLessOrEqual 100 -Because "APIM has a 100 fragment limit"
        }
    }
    
    Context "CSS Consistency" {
        It "All fragments should have the same CSS content" {
            $cssContents = @{}
            
            foreach ($page in 100..110) {
                $fragmentFile = Join-Path $fragmentPath "page-$page.xml"
                [xml]$xml = Get-Content $fragmentFile -Raw
                
                $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
                $htmlContent = $setBody.'#cdata-section'
                
                # Extract CSS content
                if ($htmlContent -match '<style>(.*?)</style>') {
                    $cssContents[$page] = $matches[1]
                }
            }
            
            # Compare all CSS contents
            $uniqueCssCount = ($cssContents.Values | Sort-Object -Unique).Count
            $uniqueCssCount | Should -Be 1 -Because "All fragments should use the same CSS"
        }
    }
}

Describe "Security Validation" {
    Context "XSS Prevention" {
        It "Fragment page-<_>.xml should not have unescaped CDATA terminators" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            $content = Get-Content $fragmentFile -Raw
            
            # Check for ]]> inside CDATA that isn't properly escaped
            # Properly escaped: ]]]]><![CDATA[>
            $cdataPattern = '<!\[CDATA\[(.*?)\]\]>'
            if ($content -match $cdataPattern) {
                $cdataContent = $matches[1]
                
                # If ]]> exists in CDATA content, it must be escaped
                if ($cdataContent -match '\]\]>') {
                    $cdataContent | Should -Match '\]\]\]\]><!\[CDATA\[>' -Because "]]> must be escaped inside CDATA"
                }
            }
        }
        
        It "Fragment page-<_>.xml should not have inline event handlers in HTML" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            # Check for onclick, onerror, etc.
            $htmlContent | Should -Not -Match '\son\w+\s*=' -Because "Inline event handlers are XSS risks"
        }
        
        It "Fragment page-<_>.xml should not use eval() or Function()" -ForEach (100..110) {
            $fragmentFile = Join-Path $fragmentPath "page-$_.xml"
            [xml]$xml = Get-Content $fragmentFile -Raw
            
            $setBody = $xml.DocumentElement.SelectSingleNode('set-body')
            $htmlContent = $setBody.'#cdata-section'
            
            $htmlContent | Should -Not -Match '\beval\s*\(' -Because "eval() is dangerous"
            $htmlContent | Should -Not -Match '\bnew\s+Function\s*\(' -Because "Function constructor is dangerous"
        }
    }
}
