// Staging environment orchestration for TXT TV
// Production-like environment for testing before production deployment

targetScope = 'resourceGroup'

@description('Environment name')
param environmentName string = 'staging'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name for resources')
param baseName string = 'txttv'

@description('Publisher email for APIM')
param apimPublisherEmail string

@description('Publisher name for APIM')
param apimPublisherName string = 'TXT TV Staging'

// Common tags
var tags = {
  Environment: environmentName
  Project: 'TXT TV'
  ManagedBy: 'Bicep'
}

// Resource naming
var storageAccountName = replace('${baseName}${environmentName}st', '-', '')
var functionAppName = '${baseName}-${environmentName}-func'
var apimName = '${baseName}-${environmentName}-apim'
var appGatewayName = '${baseName}-${environmentName}-appgw'
var wafPolicyName = '${baseName}-${environmentName}-waf'
var vnetName = '${baseName}-${environmentName}-vnet'
var appInsightsName = '${baseName}-${environmentName}-ai'
var logAnalyticsName = '${baseName}-${environmentName}-law'

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 60
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Storage Account
module storage '../modules/storage/main.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
    skuName: 'Standard_GRS' // Geo-redundant for staging
  }
}

// WAF Policy
module waf '../modules/waf/main.bicep' = {
  name: 'waf-deployment'
  params: {
    wafPolicyName: wafPolicyName
    location: location
    tags: tags
    wafMode: 'Prevention'
    rateLimitPerMinute: 100
  }
}

// Azure Functions Backend
module backend '../modules/backend/main.bicep' = {
  name: 'backend-deployment'
  params: {
    functionAppName: functionAppName
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    storageConnectionString: storage.outputs.connectionString
    appInsightsConnectionString: appInsights.properties.ConnectionString
  }
}

// API Management
module apim '../modules/apim/main.bicep' = {
  name: 'apim-deployment'
  params: {
    apimName: apimName
    location: location
    tags: tags
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    appInsightsId: appInsights.id
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    backendFunctionUrl: backend.outputs.functionAppUrl
  }
}

// Application Gateway
module appGateway '../modules/app-gateway/main.bicep' = {
  name: 'appgateway-deployment'
  params: {
    appGatewayName: appGatewayName
    location: location
    tags: tags
    skuTier: 'WAF_v2'
    capacity: 2 // Higher capacity for staging
    apimGatewayUrl: apim.outputs.apimGatewayUrl
    wafPolicyId: waf.outputs.wafPolicyId
    vnetName: vnetName
  }
}

// Outputs
output storageAccountName string = storage.outputs.storageAccountName
output functionAppUrl string = backend.outputs.functionAppUrl
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output appGatewayPublicIp string = appGateway.outputs.publicIpAddress
output appGatewayFqdn string = appGateway.outputs.fqdn
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
