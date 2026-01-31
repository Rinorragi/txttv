// Azure Functions backend module for TXT TV
// Minimal F# function that returns "you found through the maze"

@description('The name of the Function App')
param functionAppName string

@description('The location for the Function App')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('The name of the storage account for the Function App')
param storageAccountName string

@description('The connection string for the storage account')
@secure()
param storageConnectionString string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string = ''

// App Service Plan (Consumption)
resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${functionAppName}-plan'
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false // Windows
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v10.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
  }
}

@description('The resource ID of the Function App')
output functionAppId string = functionApp.id

@description('The name of the Function App')
output functionAppName string = functionApp.name

@description('The default hostname of the Function App')
output functionAppHostname string = functionApp.properties.defaultHostName

@description('The URL of the Function App')
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'

@description('The principal ID of the Function App managed identity')
output principalId string = functionApp.identity.principalId
