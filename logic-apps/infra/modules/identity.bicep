@description('Name of the user-assigned managed identity.')
param name string

@description('Location of the identity.')
param location string

@description('Tags.')
param tags object = {}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output resourceId string = uami.id
output name string = uami.name
output clientId string = uami.properties.clientId
output principalId string = uami.properties.principalId
