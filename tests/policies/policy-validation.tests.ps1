# APIM Policy Validation Tests
# Validates XML syntax and structure of APIM policy files

Describe "APIM Policy Validation" {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        $policiesPath = Join-Path $repoRoot "infrastructure/modules/apim/policies"
        $fragmentsPath = Join-Path $repoRoot "infrastructure/modules/apim/fragments"
    }

    Context "Policy Files XML Validation" {
        It "Should have valid XML in global-policy.xml" {
            $policyPath = Join-Path $policiesPath "global-policy.xml"
            if (Test-Path $policyPath) {
                { [xml](Get-Content $policyPath -Raw) } | Should -Not -Throw
            }
        }

        It "Should have valid XML in page-routing-policy.xml" {
            $policyPath = Join-Path $policiesPath "page-routing-policy.xml"
            if (Test-Path $policyPath) {
                { [xml](Get-Content $policyPath -Raw) } | Should -Not -Throw
            }
        }

        It "Should have valid XML in backend-policy.xml" {
            $policyPath = Join-Path $policiesPath "backend-policy.xml"
            if (Test-Path $policyPath) {
                { [xml](Get-Content $policyPath -Raw) } | Should -Not -Throw
            }
        }
    }

    Context "Policy Fragment Files XML Validation" {
        It "Should have valid XML in error-page.xml" {
            $fragmentPath = Join-Path $fragmentsPath "error-page.xml"
            if (Test-Path $fragmentPath) {
                { [xml](Get-Content $fragmentPath -Raw) } | Should -Not -Throw
            }
        }

        It "Should have valid XML in all page fragments" {
            $pageFragments = Get-ChildItem -Path $fragmentsPath -Filter "page-*.xml" -ErrorAction SilentlyContinue
            foreach ($fragment in $pageFragments) {
                { [xml](Get-Content $fragment.FullName -Raw) } | Should -Not -Throw -Because "Fragment $($fragment.Name) should be valid XML"
            }
        }
    }

    Context "Policy Structure Validation" {
        It "Global policy should have required sections" {
            $policyPath = Join-Path $policiesPath "global-policy.xml"
            if (Test-Path $policyPath) {
                $xml = [xml](Get-Content $policyPath -Raw)
                $xml.policies.inbound | Should -Not -BeNullOrEmpty
                $xml.policies.outbound | Should -Not -BeNullOrEmpty
            }
        }

        It "Page routing policy should have choose/when conditions" {
            $policyPath = Join-Path $policiesPath "page-routing-policy.xml"
            if (Test-Path $policyPath) {
                $content = Get-Content $policyPath -Raw
                $content | Should -Match "choose"
                $content | Should -Match "when"
            }
        }
    }

    Context "Fragment Content Validation" {
        It "Page fragments should contain HTMX script reference" {
            $pageFragments = Get-ChildItem -Path $fragmentsPath -Filter "page-*.xml" -ErrorAction SilentlyContinue
            foreach ($fragment in $pageFragments) {
                $content = Get-Content $fragment.FullName -Raw
                $content | Should -Match "htmx.org" -Because "Fragment $($fragment.Name) should include HTMX"
            }
        }

        It "Page fragments should contain navigation buttons" {
            $pageFragments = Get-ChildItem -Path $fragmentsPath -Filter "page-*.xml" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "error-page.xml" -and $_.Name -ne "navigation-template.xml" }
            foreach ($fragment in $pageFragments) {
                $content = Get-Content $fragment.FullName -Raw
                $content | Should -Match "hx-get" -Because "Fragment $($fragment.Name) should have navigation"
            }
        }

        It "Page fragments should not exceed 2000 characters of content" {
            $contentPath = Join-Path $repoRoot "content/pages"
            $contentFiles = Get-ChildItem -Path $contentPath -Filter "page-*.txt" -ErrorAction SilentlyContinue
            foreach ($file in $contentFiles) {
                $content = Get-Content $file.FullName -Raw
                $content.Length | Should -BeLessOrEqual 2000 -Because "Page content $($file.Name) should not exceed 2000 chars"
            }
        }
    }
}
