@description('Logic App (Standard) site name.')
param logicAppName string

@description('App Service plan name.')
param planName string

@description('Location.')
param location string

@description('Tags.')
param tags object = {}

@description('Storage account name (used for keyless AzureWebJobsStorage settings).')
param storageAccountName string

@description('Resource ID of the user-assigned managed identity (for Graph + ADO calls).')
param userAssignedIdentityResourceId string

@description('Client ID of the user-assigned managed identity (referenced by workflow HTTP actions).')
param userAssignedIdentityClientId string

@description('Subnet ID for VNet integration (snet-app, delegated to Microsoft.App/environments).')
param vnetIntegrationSubnetId string

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

// Keyless AzureWebJobsStorage: uses the site's SYSTEM-assigned managed identity.
// Storage role assignments (Blob Data Owner / Queue Data Contributor / Table Data Contributor)
// are granted out-of-band by the storage-role-assignments module against site.identity.principalId.
var coreAppSettings = [
  {
    name: 'AzureWebJobsStorage__accountName'
    value: storageAccountName
  }
  {
    name: 'AzureWebJobsStorage__credential'
    value: 'managedidentity'
  }
  {
    name: 'AzureWebJobsStorage__blobServiceUri'
    value: 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
  }
  {
    name: 'AzureWebJobsStorage__queueServiceUri'
    value: 'https://${storageAccountName}.queue.${environment().suffixes.storage}'
  }
  {
    name: 'AzureWebJobsStorage__tableServiceUri'
    value: 'https://${storageAccountName}.table.${environment().suffixes.storage}'
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
    name: 'WEBSITE_CONTENTOVERVNET'
    value: '1'
  }
  {
    name: 'WEBSITE_VNET_ROUTE_ALL'
    value: '1'
  }
  {
    name: 'MANAGED_IDENTITY_CLIENT_ID'
    value: userAssignedIdentityClientId
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
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    keyVaultReferenceIdentity: userAssignedIdentityResourceId
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    vnetRouteAllEnabled: true
    vnetContentShareEnabled: true
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
output systemAssignedPrincipalId string = site.identity.principalId
