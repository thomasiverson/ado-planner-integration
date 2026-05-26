targetScope = 'resourceGroup'

@minLength(3)
@maxLength(11)
@description('Lowercase prefix used to derive resource names. 3–11 chars.')
param namePrefix string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Azure DevOps organization name (the segment after dev.azure.com/).')
param adoOrg string

@description('Azure DevOps project name.')
param adoProject string

@description('Work item type Flow A creates (e.g., Task, User Story).')
param adoWorkItemType string = 'Task'

@description('Microsoft 365 Group Object ID that owns the Planner plan (informational; not used by workflows directly).')
param plannerGroupId string

@description('Planner Plan ID to monitor for new tasks.')
param plannerPlanId string

@description('Tags applied to all resources.')
param tags object = {
  workload: 'planner-ado-integration-consumption'
  managedBy: 'bicep'
}

var suffix = uniqueString(resourceGroup().id, namePrefix)
var identityName = 'uami-${namePrefix}-${suffix}'
var flowAName = 'logic-${namePrefix}-flow-a-${suffix}'
var flowBName = 'logic-${namePrefix}-flow-b-${suffix}'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

resource flowA 'Microsoft.Logic/workflows@2019-05-01' = {
  name: flowAName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: loadJsonContent('../workflows/flow-a-planner-to-ado.json')
    parameters: {
      AdoOrg: { value: adoOrg }
      AdoProject: { value: adoProject }
      AdoWorkItemType: { value: adoWorkItemType }
      PlannerPlanId: { value: plannerPlanId }
      ManagedIdentityResourceId: { value: uami.id }
    }
  }
}

resource flowB 'Microsoft.Logic/workflows@2019-05-01' = {
  name: flowBName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: loadJsonContent('../workflows/flow-b-ado-to-planner.json')
    parameters: {
      AdoOrg: { value: adoOrg }
      AdoProject: { value: adoProject }
      ManagedIdentityResourceId: { value: uami.id }
    }
  }
}

output managedIdentityName string = uami.name
output managedIdentityClientId string = uami.properties.clientId
output managedIdentityPrincipalId string = uami.properties.principalId
output managedIdentityResourceId string = uami.id
output flowAName string = flowA.name
output flowAResourceId string = flowA.id
output flowBName string = flowB.name
output flowBResourceId string = flowB.id
output plannerGroupIdInfo string = plannerGroupId
