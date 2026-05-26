@description('VNet name.')
param name string

@description('Location.')
param location string

@description('Tags.')
param tags object = {}

@description('Address space CIDR.')
param addressPrefix string = '10.41.0.0/22'

@description('Subnet CIDR for Logic App VNet integration. Must be delegated to Microsoft.App/environments.')
param snetAppPrefix string = '10.41.0.0/24'

@description('Subnet CIDR for private endpoints.')
param snetPePrefix string = '10.41.1.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ addressPrefix ] }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: snetAppPrefix
          delegations: [
            {
              name: 'serverfarms-delegation'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: snetPePrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output id string = vnet.id
output name string = vnet.name
output snetAppId string = vnet.properties.subnets[0].id
output snetPeId string = vnet.properties.subnets[1].id
