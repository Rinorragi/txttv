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

// GET /content/{pageNumber} - JSON Content API
resource getContentOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: txttvApi
  name: 'get-content'
  properties: {
    displayName: 'Get Content'
    method: 'GET'
    urlTemplate: '/content/{pageNumber}'
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
        description: 'JSON content payload'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
      {
        statusCode: 400
        description: 'Invalid page number'
      }
      {
        statusCode: 404
        description: 'Page not found'
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

// Page Template (shared HTML shell - US2)
resource fragmentPageTemplate 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'page-template'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/page-template.xml')
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

// Content Fragments (JSON Content API - US1)
resource fragmentContent100 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-100'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-100.xml')
  }
}

resource fragmentContent101 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-101'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-101.xml')
  }
}

resource fragmentContent102 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-102'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-102.xml')
  }
}

resource fragmentContent103 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-103'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-103.xml')
  }
}

resource fragmentContent104 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-104'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-104.xml')
  }
}

resource fragmentContent105 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-105'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-105.xml')
  }
}

resource fragmentContent106 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-106'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-106.xml')
  }
}

resource fragmentContent107 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-107'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-107.xml')
  }
}

resource fragmentContent108 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-108'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-108.xml')
  }
}

resource fragmentContent109 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-109'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-109.xml')
  }
}

resource fragmentContent110 'Microsoft.ApiManagement/service/policyFragments@2024-05-01' = {
  parent: apim
  name: 'content-110'
  properties: {
    format: 'xml'
    value: loadTextContent('fragments/content-110.xml')
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
    fragmentPageTemplate
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

// Operation Policy for get-content (JSON Content API)
resource getContentPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-05-01' = {
  parent: getContentOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('policies/content-routing-policy.xml')
  }
  dependsOn: [
    fragmentContent100
    fragmentContent101
    fragmentContent102
    fragmentContent103
    fragmentContent104
    fragmentContent105
    fragmentContent106
    fragmentContent107
    fragmentContent108
    fragmentContent109
    fragmentContent110
  ]
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
