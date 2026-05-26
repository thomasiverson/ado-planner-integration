@description('Globally unique storage account name (3–24 lowercase chars).')
@minLength(3)
@maxLength(24)
param name string

@description('Location.')
param location string

@description('Tags.')
param tags object = {}

@description('Subnet ID to host the private endpoints (snet-pe).')
param privateEndpointSubnetId string

@description('Private DNS zone IDs for storage subresources.')
param dnsZoneIds object // { blob, queue, table, file }

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

var subresources = [
  { groupId: 'blob',  zoneId: dnsZoneIds.blob  }
  { groupId: 'queue', zoneId: dnsZoneIds.queue }
  { groupId: 'table', zoneId: dnsZoneIds.table }
  { groupId: 'file',  zoneId: dnsZoneIds.file  }
]

resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = [for sub in subresources: {
  name: 'pe-${name}-${sub.groupId}'
  location: location
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${sub.groupId}'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [ sub.groupId ]
        }
      }
    ]
  }
}]

resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = [for (sub, i) in subresources: {
  parent: pe[i]
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: sub.groupId
        properties: { privateDnsZoneId: sub.zoneId }
      }
    ]
  }
}]

output name string = storage.name
output resourceId string = storage.id
output blobEndpoint string = storage.properties.primaryEndpoints.blob
output queueEndpoint string = storage.properties.primaryEndpoints.queue
output tableEndpoint string = storage.properties.primaryEndpoints.table
