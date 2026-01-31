// XSS protection rule for TXT TV WAF
// Blocks common cross-site scripting patterns

output customRule object = {
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
      negationCondition: false
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

output description string = 'XSS protection: Blocks script tags and event handlers'
