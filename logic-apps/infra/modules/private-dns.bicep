@description('Resource ID of the VNet to link the zones to.')
param vnetId string

@description('Tags.')
param tags object = {}

var zoneNames = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
]

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zoneName in zoneNames: {
  name: zoneName
  location: 'global'
  tags: tags
}]

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, i) in zoneNames: {
  parent: zones[i]
  name: 'link-${uniqueString(vnetId)}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}]

output blobZoneId string = zones[0].id
output queueZoneId string = zones[1].id
output tableZoneId string = zones[2].id
output fileZoneId string = zones[3].id
