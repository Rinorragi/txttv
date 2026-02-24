# APIM Policy Validation Tests
# Validates XML syntax and structure of APIM policy files
# Updated for two-API architecture: page-routing + content-routing policies

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

        It "Should have valid XML in content-routing-policy.xml" {
            $policyPath = Join-Path $policiesPath "content-routing-policy.xml"
            Test-Path $policyPath | Should -BeTrue
            { [xml](Get-Content $policyPath -Raw) } | Should -Not -Throw
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

        It "Should have valid XML in page-template.xml" {
            $fragmentPath = Join-Path $fragmentsPath "page-template.xml"
            Test-Path $fragmentPath | Should -BeTrue
            { [xml](Get-Content $fragmentPath -Raw) } | Should -Not -Throw
        }

        It "Should have valid XML in all content fragments" {
            $contentFragments = Get-ChildItem -Path $fragmentsPath -Filter "content-*.xml" -ErrorAction SilentlyContinue
            $contentFragments.Count | Should -Be 11
            foreach ($fragment in $contentFragments) {
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

        It "Page routing policy should include page-template fragment" {
            $policyPath = Join-Path $policiesPath "page-routing-policy.xml"
            if (Test-Path $policyPath) {
                $content = Get-Content $policyPath -Raw
                $content | Should -Match 'include-fragment'
                $content | Should -Match 'page-template'
            }
        }

        It "Page routing policy should validate pageNumber input" {
            $policyPath = Join-Path $policiesPath "page-routing-policy.xml"
            if (Test-Path $policyPath) {
                $content = Get-Content $policyPath -Raw
                $content | Should -Match 'pageNumber' -Because "Should extract pageNumber from URL"
            }
        }
    }

    Context "Content Routing Policy Validation" {
        BeforeAll {
            $script:contentPolicyPath = Join-Path $policiesPath "content-routing-policy.xml"
            $script:contentPolicyContent = Get-Content $script:contentPolicyPath -Raw
            $script:contentPolicyXml = [xml]$script:contentPolicyContent
        }

        It "Should have choose/when conditions for content dispatch" {
            $script:contentPolicyContent | Should -Match 'choose'
            $script:contentPolicyContent | Should -Match 'when'
        }

        It "Should have a when clause for each page 100-110" {
            foreach ($page in 100..110) {
                $script:contentPolicyContent | Should -Match "content-$page" -Because "Should dispatch to content-$page fragment"
            }
        }

        It "Should have include-fragment for each content page" {
            foreach ($page in 100..110) {
                $script:contentPolicyContent | Should -Match "include-fragment.*fragment-id=`"content-$page`"" -Because "Should include content-$page fragment"
            }
        }

        It "Should have otherwise clause returning 404 JSON" {
            $script:contentPolicyContent | Should -Match 'otherwise'
            $script:contentPolicyContent | Should -Match '404'
            $script:contentPolicyContent | Should -Match 'Page not found'
        }

        It "Should validate pageNumber format (3-digit)" {
            $script:contentPolicyContent | Should -Match 'pageNumber'
            $script:contentPolicyContent | Should -Match '400' -Because "Should return 400 for invalid format"
        }

        It "Fragment IDs in policy should match existing content fragments" {
            $contentFragments = Get-ChildItem -Path $fragmentsPath -Filter "content-*.xml" -ErrorAction SilentlyContinue
            $fragmentIds = $contentFragments | ForEach-Object {
                $_.BaseName  # e.g., "content-100"
            }

            foreach ($id in $fragmentIds) {
                $script:contentPolicyContent | Should -Match "fragment-id=`"$id`"" -Because "Policy should reference existing fragment $id"
            }
        }
    }

    Context "Fragment Content Validation" {
        It "Page template fragment should include content-renderer script" {
            $templatePath = Join-Path $fragmentsPath "page-template.xml"
            $content = Get-Content $templatePath -Raw
            $content | Should -Match "TxtTvContentRenderer" -Because "Page template should include content renderer"
        }

        It "Page template fragment should include HTMX" {
            $templatePath = Join-Path $fragmentsPath "page-template.xml"
            $content = Get-Content $templatePath -Raw
            $content | Should -Match "htmx.org" -Because "Page template should include HTMX"
        }

        It "Page template should have page-content element for dynamic loading" {
            $templatePath = Join-Path $fragmentsPath "page-template.xml"
            $content = Get-Content $templatePath -Raw
            $content | Should -Match 'id="page-content"' -Because "Page template needs a target element for content rendering"
        }

        It "Content files should have valid JSON and not exceed 2000 characters of content" {
            $contentPath = Join-Path $repoRoot "content/pages"
            $contentFiles = Get-ChildItem -Path $contentPath -Filter "page-*.json" -ErrorAction SilentlyContinue
            foreach ($file in $contentFiles) {
                $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $json.content.Length | Should -BeLessOrEqual 2000 -Because "Page content $($file.Name) should not exceed 2000 chars"
            }
        }
    }
}
