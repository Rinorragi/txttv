// WAF Policy module for TXT TV
// Implements OWASP CRS 3.2 with custom rules for rate limiting and attack prevention

@description('The name of the WAF policy')
param wafPolicyName string

@description('The location for the WAF policy')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('WAF mode - Detection or Prevention')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('Rate limit threshold (requests per minute per IP)')
param rateLimitPerMinute int = 100

// WAF Policy
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    customRules: [
      // Rate limiting rule - 100 requests per minute per IP
      {
        name: 'RateLimitPerIP'
        priority: 10
        ruleType: 'RateLimitRule'
        rateLimitDuration: 'OneMin'
        rateLimitThreshold: rateLimitPerMinute
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RemoteAddr'
              }
            ]
            operator: 'IPMatch'
            negationConditon: true
            matchValues: [
              '127.0.0.1'
            ]
          }
        ]
        action: 'Block'
        state: 'Enabled'
      }
      // Block SQL injection attempts in query parameters
      {
        name: 'BlockSQLInjection'
        priority: 20
        ruleType: 'MatchRule'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'QueryString'
              }
            ]
            operator: 'Contains'
            negationConditon: false
            matchValues: [
              'select'
              'insert'
              'update'
              'delete'
              'drop'
              'union'
              '--'
              ';'
              '\''
            ]
            transforms: [
              'Lowercase'
              'UrlDecode'
            ]
          }
        ]
        action: 'Block'
        state: 'Enabled'
      }
      // Block XSS attempts
      {
        name: 'BlockXSS'
        priority: 30
        ruleType: 'MatchRule'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'QueryString'
              }
              {
                variableName: 'RequestUri'
              }
            ]
            operator: 'Contains'
            negationConditon: false
            matchValues: [
              '<script'
              'javascript:'
              'onerror='
              'onload='
              'onclick='
              'eval('
            ]
            transforms: [
              'Lowercase'
              'UrlDecode'
              'HtmlEntityDecode'
            ]
          }
        ]
        action: 'Block'
        state: 'Enabled'
      }
      // Block path traversal attempts
      {
        name: 'BlockPathTraversal'
        priority: 40
        ruleType: 'MatchRule'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RequestUri'
              }
            ]
            operator: 'Contains'
            negationConditon: false
            matchValues: [
              '../'
              '..%2f'
              '..%5c'
              '%2e%2e%2f'
              '%2e%2e/'
              '.%2e/'
            ]
            transforms: [
              'Lowercase'
              'UrlDecode'
            ]
          }
        ]
        action: 'Block'
        state: 'Enabled'
      }
    ]
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 1
      state: 'Enabled'
      mode: wafMode
      requestBodyInspectLimitInKB: 128
      fileUploadEnforcement: true
      requestBodyEnforcement: true
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
      exclusions: []
    }
  }
}

@description('The resource ID of the WAF policy')
output wafPolicyId string = wafPolicy.id

@description('The name of the WAF policy')
output wafPolicyName string = wafPolicy.name
