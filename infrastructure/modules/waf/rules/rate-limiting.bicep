// Rate limiting rule for TXT TV WAF
// Implements 100 requests per minute per IP address

@description('Rate limit threshold (requests per minute)')
param rateLimitPerMinute int = 100

// This module outputs the rate limiting custom rule configuration
// to be included in the main WAF policy

output customRule object = {
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

output description string = 'Rate limiting: ${rateLimitPerMinute} requests per minute per IP'
