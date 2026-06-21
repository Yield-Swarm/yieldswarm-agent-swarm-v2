@description('YieldSwarm Odysseus workspace on Azure App Service — AI Foundry env injection')
param location string = resourceGroup().location
param appName string = 'yieldswarm-odysseus-${uniqueString(resourceGroup().id)}'
param azureAiFoundryEndpoint string = 'https://yieldswarmazuurecustomm-resource.services.ai.azure.com/api/projects/yieldswarmazuurecustommmllm'
param azureAiFoundryResourceId string = '/subscriptions/1aac4ca0-686f-43b7-92a4-d523d3ec47dc/resourceGroups/rg-cbreezy666-2775/providers/Microsoft.CognitiveServices/accounts/yieldswarmazuurecustomm-resource/projects/yieldswarmazuurecustommmllm'

@secure()
param azureAiFoundryKey string

var appServicePlanName = '${appName}-plan'

resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B2'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2022-09-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appSettings: [
        { name: 'NODE_ENV', value: 'production' }
        { name: 'WEBSITES_PORT', value: '7000' }
        { name: 'AZURE_AI_FOUNDRY_ENDPOINT', value: azureAiFoundryEndpoint }
        { name: 'AZURE_AI_FOUNDRY_RESOURCE_ID', value: azureAiFoundryResourceId }
        { name: 'AZURE_AI_FOUNDRY_KEY', value: azureAiFoundryKey }
        { name: 'AZURE_AI_FOUNDRY_STRICT', value: '1' }
        { name: 'GEOD_CRON_ENABLED', value: '1' }
        { name: 'GEOD_CRON_EXPRESSION', value: '*/15 * * * *' }
        { name: 'GEOD_ENTROPY_SHARD_COUNT', value: '120' }
        { name: 'LITELLM_BASE_URL', value: 'http://127.0.0.1:4000/v1' }
        { name: 'ODYSSEUS_CHROMA_HOST', value: '127.0.0.1' }
        { name: 'ODYSSEUS_CHROMA_PORT', value: '8000' }
      ]
      alwaysOn: true
    }
  }
}

output appUrl string = 'https://${app.properties.defaultHostName}'
output appName string = app.name
