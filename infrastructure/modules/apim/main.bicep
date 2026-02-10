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
