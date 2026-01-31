// SQL Injection protection rule for TXT TV WAF
// Blocks common SQL injection patterns in query strings

output customRule object = {
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

output description string = 'SQL injection protection: Blocks common SQL keywords and patterns'
