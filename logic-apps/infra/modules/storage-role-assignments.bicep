@description('Storage account resource ID.')
param storageAccountId string

@description('Principal IDs (Service Principal type) to grant Blob/Queue/Table data roles to.')
param principalIds array

var blobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var queueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var tableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

var roleIds = [
  blobDataOwnerRoleId
  queueDataContributorRoleId
  tableDataContributorRoleId
]

var roleCount = length(roleIds)
var totalCount = length(principalIds) * roleCount

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: last(split(storageAccountId, '/'))
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, totalCount): {
  name: guid(storageAccountId, principalIds[i / roleCount], roleIds[i % roleCount])
  scope: storage
  properties: {
    principalId: principalIds[i / roleCount]
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[i % roleCount])
  }
}]
