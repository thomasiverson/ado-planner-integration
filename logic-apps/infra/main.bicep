targetScope = 'resourceGroup'

@minLength(3)
@maxLength(11)
@description('Lowercase prefix used to derive resource names. 3–11 chars.')
param namePrefix string = 'plannerado'

@description('Azure region for all resources. Must support Logic Apps Standard.')
param location string = resourceGroup().location

@description('Azure DevOps organization name (the segment after dev.azure.com/).')
param adoOrg string

@description('Azure DevOps project name.')
param adoProject string

@description('Work item type Flow A creates (e.g., Task, User Story).')
param adoWorkItemType string = 'Task'

@description('Microsoft 365 Group Object ID that owns the Planner plan.')
param plannerGroupId string

@description('Planner Plan ID to monitor for new tasks.')
param plannerPlanId string

@description('Provision Application Insights for workflow telemetry.')
param enableAppInsights bool = true

@description('VNet address space. Avoid collisions with other workloads in the subscription.')
param vnetAddressPrefix string = '10.41.0.0/22'

@description('Subnet for Logic App VNet integration.')
param snetAppPrefix string = '10.41.0.0/24'

@description('Subnet for private endpoints.')
param snetPePrefix string = '10.41.1.0/24'

@description('Tags applied to all resources.')
param tags object = {
  workload: 'planner-ado-integration'
  managedBy: 'bicep'
}

var suffix = uniqueString(resourceGroup().id, namePrefix)
var storageAccountName = toLower(take('st${namePrefix}${suffix}', 24))
var planName = 'plan-${namePrefix}-${suffix}'
var logicAppName = 'la-${namePrefix}-${suffix}'
var identityName = 'uami-${namePrefix}-${suffix}'
var appInsightsName = 'appi-${namePrefix}-${suffix}'
var logAnalyticsName = 'log-${namePrefix}-${suffix}'
var vnetName = 'vnet-${namePrefix}-${suffix}'

module vnet 'modules/vnet.bicep' = {
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefix: vnetAddressPrefix
    snetAppPrefix: snetAppPrefix
    snetPePrefix: snetPePrefix
  }
}

module dns 'modules/private-dns.bicep' = {
  params: {
    vnetId: vnet.outputs.id
    tags: tags
  }
}

module identity 'modules/identity.bicep' = {
  params: {
    name: identityName
    location: location
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  params: {
    name: storageAccountName
    location: location
    tags: tags
    privateEndpointSubnetId: vnet.outputs.snetPeId
    dnsZoneIds: {
      blob: dns.outputs.blobZoneId
      queue: dns.outputs.queueZoneId
      table: dns.outputs.tableZoneId
      file: dns.outputs.fileZoneId
    }
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (enableAppInsights) {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

module logicApp 'modules/logic-app.bicep' = {
  params: {
    logicAppName: logicAppName
    planName: planName
    location: location
    tags: tags
    storageAccountName: storage.outputs.name
    userAssignedIdentityResourceId: identity.outputs.resourceId
    userAssignedIdentityClientId: identity.outputs.clientId
    vnetIntegrationSubnetId: vnet.outputs.snetAppId
    appInsightsConnectionString: enableAppInsights ? (appInsights.?properties.?ConnectionString ?? '') : ''
    appSettings: {
      ADO_ORG: adoOrg
      ADO_PROJECT: adoProject
      ADO_WORK_ITEM_TYPE: adoWorkItemType
      PLANNER_GROUP_ID: plannerGroupId
      PLANNER_PLAN_ID: plannerPlanId
    }
  }
}

module storageRoles 'modules/storage-role-assignments.bicep' = {
  params: {
    storageAccountId: storage.outputs.resourceId
    principalIds: [
      logicApp.outputs.systemAssignedPrincipalId
      identity.outputs.principalId
    ]
  }
}

output logicAppName string = logicApp.outputs.name
output logicAppHostname string = logicApp.outputs.defaultHostName
output logicAppResourceId string = logicApp.outputs.resourceId
output managedIdentityName string = identity.outputs.name
output managedIdentityClientId string = identity.outputs.clientId
output managedIdentityPrincipalId string = identity.outputs.principalId
output logicAppSystemPrincipalId string = logicApp.outputs.systemAssignedPrincipalId
output storageAccountName string = storage.outputs.name
output vnetName string = vnet.outputs.name
output appInsightsName string = enableAppInsights ? (appInsights.?name ?? '') : ''
