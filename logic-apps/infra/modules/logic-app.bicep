@description('Logic App (Standard) site name.')
param logicAppName string

@description('App Service plan name.')
param planName string

@description('Location.')
param location string

@description('Tags.')
param tags object = {}

@description('Storage account name for runtime backing.')
param storageAccountName string

@description('Storage account primary key (used by Logic Apps runtime). Stored only in app settings.')
@secure()
param storageAccountKey string

@description('Resource ID of the user-assigned managed identity.')
param managedIdentityResourceId string

@description('Client ID of the user-assigned managed identity (referenced by workflow HTTP actions).')
param managedIdentityClientId string

@description('App Insights connection string. Empty string disables telemetry.')
param appInsightsConnectionString string = ''

@description('Workflow-facing application settings (env vars, IDs, etc.).')
param appSettings object = {}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  kind: 'elastic'
  properties: {
    targetWorkerCount: 1
    maximumElasticWorkerCount: 20
    elasticScaleEnabled: true
    zoneRedundant: false
  }
}

var coreAppSettings = [
  {
    name: 'AzureWebJobsStorage'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'WEBSITE_CONTENTSHARE'
    value: toLower(logicAppName)
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'node'
  }
  {
    name: 'WEBSITE_NODE_DEFAULT_VERSION'
    value: '~18'
  }
  {
    name: 'AzureFunctionsJobHost__extensionBundle__id'
    value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
  }
  {
    name: 'AzureFunctionsJobHost__extensionBundle__version'
    value: '[1.*, 2.0.0)'
  }
  {
    name: 'APP_KIND'
    value: 'workflowApp'
  }
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '1'
  }
  {
    name: 'MANAGED_IDENTITY_CLIENT_ID'
    value: managedIdentityClientId
  }
]

var telemetrySettings = empty(appInsightsConnectionString) ? [] : [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
]

var customSettings = [for setting in items(appSettings): {
  name: setting.key
  value: string(setting.value)
}]

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  location: location
  tags: tags
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityResourceId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    keyVaultReferenceIdentity: managedIdentityResourceId
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      use32BitWorkerProcess: false
      alwaysOn: false
      netFrameworkVersion: 'v6.0'
      appSettings: concat(coreAppSettings, telemetrySettings, customSettings)
    }
  }
}

output name string = site.name
output resourceId string = site.id
output defaultHostName string = site.properties.defaultHostName
