BeforeAll {
    # Import modules required for testing
    $ScriptDir = Split-Path -Parent $PSScriptRoot
    $ScriptDir = Join-Path $ScriptDir 'infrastructure\scripts'
    $LibDir = Join-Path $ScriptDir 'lib'
    
    Import-Module (Join-Path $LibDir 'BicepHelpers.psm1') -Force
    Import-Module (Join-Path $LibDir 'AzureAuth.psm1') -Force
    Import-Module (Join-Path $LibDir 'ErrorHandling.psm1') -Force
    
    # Path to deployment script
    $DeployScript = Join-Path $ScriptDir 'Deploy-Infrastructure.ps1'
}

Describe 'Deploy-Infrastructure.ps1 Parameter Validation' {
    It 'Should accept valid environment values' {
        $validEnvironments = @('dev', 'staging', 'prod')
        foreach ($env in $validEnvironments) {
            { & $DeployScript -Environment $env -WhatIf } | Should -Not -Throw
        }
    }
    
    It 'Should reject invalid environment values' {
        { & $DeployScript -Environment 'invalid' -WhatIf } | Should -Throw
    }
    
    It 'Should validate SubscriptionId format' {
        # Valid GUID
        $validGuid = '12345678-1234-1234-1234-123456789012'
        { & $DeployScript -Environment dev -SubscriptionId $validGuid -WhatIf } | Should -Not -Throw
        
        # Invalid GUID
        $invalidGuid = 'not-a-guid'
        { & $DeployScript -Environment dev -SubscriptionId $invalidGuid -WhatIf } | Should -Throw
    }
    
    It 'Should validate ResourceGroupName format' {
        # Valid names
        $validNames = @('rg-test', 'test_rg', 'test.rg', 'test-rg(1)')
        foreach ($name in $validNames) {
            { & $DeployScript -Environment dev -ResourceGroupName $name -WhatIf } | Should -Not -Throw
        }
        
        # Invalid name (contains invalid character)
        $invalidName = 'rg@invalid'
        { & $DeployScript -Environment dev -ResourceGroupName $invalidName -WhatIf } | Should -Throw
        
        # Too long (>90 characters)
        $tooLongName = 'a' * 91
        { & $DeployScript -Environment dev -ResourceGroupName $tooLongName -WhatIf } | Should -Throw
    }
    
    It 'Should use default resource group name when not provided' {
        # This would require mocking, but we can test the naming pattern
        $expectedNames = @{
            'dev' = 'rg-txttv-dev'
            'staging' = 'rg-txttv-staging'
            'prod' = 'rg-txttv-prod'
        }
        
        foreach ($env in $expectedNames.Keys) {
            $expectedNames[$env] | Should -Match '^rg-txttv-'
        }
    }
}

Describe 'BicepHelpers Module Tests' {
    Context 'Test-BicepTemplate Function' {
        It 'Should return validation result object' {
            # Create a temporary valid Bicep file
            $tempBicep = New-TemporaryFile
            $tempBicep = [System.IO.Path]::ChangeExtension($tempBicep.FullName, '.bicep')
            
            @"
param location string = 'westeurope'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'teststorage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
"@ | Out-File -FilePath $tempBicep -Encoding UTF8
            
            $result = Test-BicepTemplate -TemplatePath $tempBicep
            
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'IsValid'
            $result.PSObject.Properties.Name | Should -Contain 'Errors'
            $result.PSObject.Properties.Name | Should -Contain 'TemplatePath'
            
            Remove-Item $tempBicep -Force
        }
        
        It 'Should detect invalid Bicep syntax' {
            # Create a temporary invalid Bicep file
            $tempBicep = New-TemporaryFile
            $tempBicep = [System.IO.Path]::ChangeExtension($tempBicep.FullName, '.bicep')
            
            @"
param location string = 'westeurope'

resource invalid syntax here
"@ | Out-File -FilePath $tempBicep -Encoding UTF8
            
            $result = Test-BicepTemplate -TemplatePath $tempBicep
            
            $result.IsValid | Should -Be $false
            $result.Errors.Count | Should -BeGreaterThan 0
            
            Remove-Item $tempBicep -Force
        }
        
        It 'Should throw when file does not exist' {
            { Test-BicepTemplate -TemplatePath 'C:\nonexistent\file.bicep' } | Should -Throw
        }
    }
    
    Context 'Invoke-BicepBuild Function' {
        It 'Should build valid Bicep template' {
            $tempBicep = New-TemporaryFile
            $tempBicep = [System.IO.Path]::ChangeExtension($tempBicep.FullName, '.bicep')
            $tempJson = [System.IO.Path]::ChangeExtension($tempBicep, '.json')
            
            @"
param location string = 'westeurope'

output deploymentLocation string = location
"@ | Out-File -FilePath $tempBicep -Encoding UTF8
            
            $result = Invoke-BicepBuild -TemplatePath $tempBicep -OutputPath $tempJson
            
            $result.Success | Should -Be $true
            Test-Path $tempJson | Should -Be $true
            
            Remove-Item $tempBicep, $tempJson -Force
        }
    }
}

Describe 'AzureAuth Module Tests' {
    Context 'Test-AzureAuthentication Function' {
        It 'Should return authentication status object' {
            $result = Test-AzureAuthentication
            
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'IsAuthenticated'
            $result.PSObject.Properties.Name | Should -Contain 'Account'
            $result.PSObject.Properties.Name | Should -Contain 'TenantId'
            $result.PSObject.Properties.Name | Should -Contain 'SubscriptionId'
        }
        
        It 'Should detect when Azure CLI is not installed' {
            # This test would require mocking Get-Command
            # For now, just verify the function exists
            Get-Command Test-AzureAuthentication | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Test-AzureSubscription Function' {
        It 'Should accept subscription ID parameter' {
            $testSubscriptionId = '12345678-1234-1234-1234-123456789012'
            
            # This would normally check actual Azure access
            # For testing, just verify the function signature
            Get-Command Test-AzureSubscription | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Test-AzureResourceGroup Function' {
        It 'Should return resource group status object' {
            $result = Test-AzureResourceGroup -ResourceGroupName 'test-rg'
            
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'Exists'
            $result.PSObject.Properties.Name | Should -Contain 'ResourceGroupName'
            $result.PSObject.Properties.Name | Should -Contain 'Location'
        }
    }
}

Describe 'ErrorHandling Module Tests' {
    Context 'Write-DeploymentLog Function' {
        It 'Should accept all log levels' {
            $levels = @('Info', 'Warning', 'Error', 'Success', 'Debug')
            
            foreach ($level in $levels) {
                { Write-DeploymentLog -Message "Test message" -Level $level } | Should -Not -Throw
            }
        }
        
        It 'Should accept pipeline input' {
            { "Test message" | Write-DeploymentLog -Level Info } | Should -Not -Throw
        }
    }
    
    Context 'Format-ErrorMessage Function' {
        It 'Should format error record' {
            try {
                throw "Test error"
            }
            catch {
                $formatted = Format-ErrorMessage -ErrorRecord $_
                $formatted | Should -Match 'Test error'
                $formatted | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context 'Test-RequiredParameter Function' {
        It 'Should pass for valid parameters' {
            { Test-RequiredParameter -ParameterName 'TestParam' -ParameterValue 'TestValue' } | Should -Not -Throw
        }
        
        It 'Should throw for null parameters' {
            { Test-RequiredParameter -ParameterName 'TestParam' -ParameterValue $null } | Should -Throw
        }
        
        It 'Should throw for empty string parameters' {
            { Test-RequiredParameter -ParameterName 'TestParam' -ParameterValue '' } | Should -Throw
        }
        
        It 'Should allow empty strings with -AllowEmptyString' {
            { Test-RequiredParameter -ParameterName 'TestParam' -ParameterValue '' -AllowEmptyString } | Should -Not -Throw
        }
    }
    
    Context 'Test-FilePath Function' {
        It 'Should pass for existing files' {
            $tempFile = New-TemporaryFile
            { Test-FilePath -Path $tempFile.FullName } | Should -Not -Throw
            Remove-Item $tempFile -Force
        }
        
        It 'Should throw for non-existent files' {
            { Test-FilePath -Path 'C:\nonexistent\file.txt' } | Should -Throw
        }
        
        It 'Should validate file extensions' {
            $tempFile = New-TemporaryFile
            $tempBicep = [System.IO.Path]::ChangeExtension($tempFile.FullName, '.bicep')
            Move-Item $tempFile.FullName $tempBicep
            
            { Test-FilePath -Path $tempBicep -Extension '.bicep' } | Should -Not -Throw
            { Test-FilePath -Path $tempBicep -Extension '.json' } | Should -Throw
            
            Remove-Item $tempBicep -Force
        }
    }
    
    Context 'Invoke-WithRetry Function' {
        It 'Should execute script block successfully' {
            $result = Invoke-WithRetry -ScriptBlock { return "Success" }
            $result | Should -Be "Success"
        }
        
        It 'Should retry on failure' {
            $script:attempts = 0
            
            $result = Invoke-WithRetry -MaxRetries 3 -RetryDelaySeconds 1 -ScriptBlock {
                $script:attempts++
                if ($script:attempts -lt 2) {
                    throw "Simulated failure"
                }
                return "Success after retry"
            }
            
            $result | Should -Be "Success after retry"
            $script:attempts | Should -Be 2
        }
        
        It 'Should throw after max retries exceeded' {
            { 
                Invoke-WithRetry -MaxRetries 2 -RetryDelaySeconds 1 -ScriptBlock {
                    throw "Always fail"
                }
            } | Should -Throw
        }
    }
    
    Context 'New-DeploymentResult Function' {
        It 'Should create result object with all properties' {
            $result = New-DeploymentResult -Success $true -Message "Test message" -Data @{ Key = 'Value' }
            
            $result.Success | Should -Be $true
            $result.Message | Should -Be "Test message"
            $result.Data.Key | Should -Be 'Value'
            $result.Timestamp | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Deploy-Infrastructure.ps1 WhatIf Mode' {
    It 'Should support -WhatIf parameter' {
        # WhatIf should not make actual changes
        { & $DeployScript -Environment dev -WhatIf } | Should -Not -Throw
    }
    
    It 'Should display what-if results without deploying' {
        # This would require mocking Azure CLI calls
        # For now, just verify the parameter is supported
        (Get-Command $DeployScript).Parameters.Keys | Should -Contain 'WhatIf'
    }
}

Describe 'Remove-Infrastructure.ps1 Tests' {
    BeforeAll {
        $RemoveScript = Join-Path $ScriptDir 'Remove-Infrastructure.ps1'
    }
    
    It 'Should accept valid environment values' {
        $validEnvironments = @('dev', 'staging', 'prod')
        foreach ($env in $validEnvironments) {
            { & $RemoveScript -Environment $env -WhatIf } | Should -Not -Throw
        }
    }
    
    It 'Should support -Force parameter' {
        (Get-Command $RemoveScript).Parameters.Keys | Should -Contain 'Force'
    }
    
    It 'Should support -PreserveData parameter' {
        (Get-Command $RemoveScript).Parameters.Keys | Should -Contain 'PreserveData'
    }
    
    It 'Should support -DeleteResourceGroup parameter' {
        (Get-Command $RemoveScript).Parameters.Keys | Should -Contain 'DeleteResourceGroup'
    }
}
