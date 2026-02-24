// Azure API Management module for TXT TV
// PRIMARY implementation surface - policy fragments render TXT TV pages

@description('The name of the APIM instance')
param apimName string

@description('The location for APIM')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('Publisher email for APIM')
param publisherEmail string

@description('Publisher name for APIM')
param publisherName string

@description('Application Insights resource ID for logging')
param appInsightsId string = ''

@description('Application Insights instrumentation key')
@secure()
param appInsightsInstrumentationKey string = ''

@description('Backend Function App URL')
param backendFunctionUrl string = ''

@description('Application Gateway public IP for access restriction')
param appGatewayPublicIp string = ''

@description('APIM SKU name')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Developer'

// APIM Instance (Developer tier for dev/test environment)
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuName == 'Consumption' ? 0 : 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Application Insights Logger
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = if (!empty(appInsightsId)) {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

// TXT TV API
resource txttvApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'txttv-api'
  properties: {
    displayName: 'TXT TV API'
    description: 'TXT TV application with policy-based HTML rendering'
    subscriptionRequired: false
    path: ''
    protocols: [
      'https'
    ]
    serviceUrl: backendFunctionUrl
  }
}

// GET /page/{pageNumber} - Main page rendering operation
resource getPageOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: txttvApi
  name: 'get-page'
  properties: {
    displayName: 'Get Page'
    method: 'GET'
    urlTemplate: '/page/{pageNumber}'
    templateParameters: [
      {
        name: 'pageNumber'
        type: 'integer'
        required: true
        description: 'Page number (100-999)'
      }
    ]
    responses: [
      {
        statusCode: 200
        description: 'HTML page content'
        representations: [
          {
            contentType: 'text/html'
          }
        ]
      }
      {
        statusCode: 400
        description: 'Invalid page number'
      }
    ]
  }
}

// GET / - Home page redirect
resource getHomeOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: txttvApi
  name: 'get-home'
  properties: {
    displayName: 'Get Home'
    method: 'GET'
    urlTemplate: '/'
    responses: [
      {
        statusCode: 302
        description: 'Redirect to page 100'
      }
    ]
  }
}

// GET /backend-test - Backend connectivity test
resource getBackendTestOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: txttvApi
  name: 'get-backend-test'
  properties: {
    displayName: 'Backend Test'
    method: 'GET'
    urlTemplate: '/backend-test'
    responses: [
      {
        statusCode: 200
        description: 'Backend confirmation message'
        representations: [
          {
            contentType: 'text/plain'
          }
        ]
      }
    ]
  }
}

// Backend for Function App
resource functionBackend 'Microsoft.ApiManagement/service/backends@2024-05-01' = if (!empty(backendFunctionUrl)) {
  parent: apim
  name: 'function-backend'
  properties: {
    url: backendFunctionUrl
    protocol: 'http'
    description: 'TXT TV F# Function Backend'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// Named Value for Function Backend URL
resource namedValueFunctionUrl 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = if (!empty(backendFunctionUrl)) {
  parent: apim
  name: 'function-backend-url'
  properties: {
    displayName: 'function-backend-url'
    value: backendFunctionUrl
    secret: false
  }
}

// Named Value for App Gateway Public IP (for access restriction)
// Always created - empty value allows all traffic, set after App Gateway deployment
resource namedValueAppGwIp 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'appgw-public-ip'
  properties: {
    displayName: 'appgw-public-ip'
    value: !empty(appGatewayPublicIp) ? appGatewayPublicIp : ''
    secret: false
  }
}

// Policy Fragments
resource fragmentPage100 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-100'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-100.xml')
  }
}

resource fragmentPage101 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-101'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-101.xml')
  }
}

resource fragmentPage102 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-102'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-102.xml')
  }
}

resource fragmentPage103 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-103'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-103.xml')
  }
}

resource fragmentPage104 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-104'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-104.xml')
  }
}

resource fragmentPage105 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-105'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-105.xml')
  }
}

resource fragmentPage106 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-106'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-106.xml')
  }
}

resource fragmentPage107 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-107'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-107.xml')
  }
}

resource fragmentPage108 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-108'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-108.xml')
  }
}

resource fragmentPage109 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-109'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-109.xml')
  }
}

resource fragmentPage110 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-110'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-110.xml')
  }
}

resource fragmentErrorPage 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'error-page'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/error-page.xml')
  }
}

resource fragmentNavigationTemplate 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'navigation-template'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/navigation-template.xml')
  }
}

// Global Policy
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2024-05-01' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policies/global-policy.xml')
  }
  dependsOn: [
    namedValueAppGwIp
  ]
}

// Operation Policy for get-page
resource getPagePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-05-01' = {
  parent: getPageOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policies/page-routing-policy.xml')
  }
  dependsOn: [
    fragmentPage100
    fragmentPage101
    fragmentPage102
    fragmentPage103
    fragmentPage104
    fragmentPage105
    fragmentPage106
    fragmentPage107
    fragmentPage108
    fragmentPage109
    fragmentPage110
    fragmentErrorPage
    fragmentNavigationTemplate
  ]
}

// Operation Policy for get-backend-test
resource getBackendTestPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-05-01' = if (!empty(backendFunctionUrl)) {
  parent: getBackendTestOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policies/backend-policy.xml')
  }
  dependsOn: [
    namedValueFunctionUrl
    functionBackend
  ]
}

// Operation Policy for get-home (redirect to page 100)
resource getHomePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-05-01' = {
  parent: getHomeOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policies/home-redirect-policy.xml')
  }
}

@description('The resource ID of the APIM instance')
output apimId string = apim.id

@description('The name of the APIM instance')
output apimName string = apim.name

@description('The gateway URL of the APIM instance')
output apimGatewayUrl string = apim.properties.gatewayUrl

@description('The principal ID of the APIM managed identity')
output principalId string = apim.identity.principalId

@description('The API ID for TXT TV API')
output txttvApiId string = txttvApi.id
