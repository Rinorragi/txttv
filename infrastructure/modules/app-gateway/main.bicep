// Application Gateway module for TXT TV
// Serves as the public entry point with WAF protection

@description('The name of the Application Gateway')
param appGatewayName string

@description('The location for the Application Gateway')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('The SKU tier for the Application Gateway')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuTier string = 'WAF_v2'

@description('The capacity (instance count) for the Application Gateway')
@minValue(1)
@maxValue(10)
param capacity int = 1

@description('The APIM gateway URL to use as backend')
param apimGatewayUrl string

@description('The WAF policy resource ID')
param wafPolicyId string = ''

@description('Virtual network name')
param vnetName string

@description('Subnet name for Application Gateway')
param subnetName string = 'appgw-subnet'

@description('Address prefix for the virtual network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the Application Gateway subnet')
param subnetAddressPrefix string = '10.0.1.0/24'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Public IP for Application Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${appGatewayName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower(appGatewayName)
    }
  }
}

// Extract APIM hostname from URL
var apimHostname = replace(replace(apimGatewayUrl, 'https://', ''), 'http://', '')

// Application Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGatewayName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuTier
      tier: skuTier
      capacity: capacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'apimBackendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: apimHostname
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'apimHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'apimProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'apimBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'apimHttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'apimProbe'
        properties: {
          protocol: 'Https'
          host: apimHostname
          path: '/status-0123456789abcdef'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    firewallPolicy: !empty(wafPolicyId) ? {
      id: wafPolicyId
    } : null
  }
}

@description('The resource ID of the Application Gateway')
output appGatewayId string = appGateway.id

@description('The name of the Application Gateway')
output appGatewayName string = appGateway.name

@description('The public IP address of the Application Gateway')
output publicIpAddress string = publicIp.properties.ipAddress

@description('The FQDN of the Application Gateway')
output fqdn string = publicIp.properties.dnsSettings.fqdn

@description('The virtual network ID')
output vnetId string = vnet.id
