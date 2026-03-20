param appName string
param location string
param administratorLogin string
@secure()
param administratorPassword string
param delegatedSubnetId string
param vnetId string

// Server name must be globally unique across Azure.
var serverName = '${appName}-mysql-${uniqueString(resourceGroup().id)}'

// ---------------------------------------------------------------------------
// Private DNS zone for MySQL Flexible Server.
// The zone name must follow the pattern: <server-name>.private.mysql.database.azure.com
// ---------------------------------------------------------------------------
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${serverName}.private.mysql.database.azure.com'
  location: 'global'
}

resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${appName}-mysql-vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ---------------------------------------------------------------------------
// MySQL 8.4 Flexible Server — VNet-integrated, no public access
// ---------------------------------------------------------------------------
resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-12-30' = {
  name: serverName
  location: location
  sku: {
    // Standard_D2ds_v4 (2 vCores, 8 GB RAM) is a reasonable starting point for
    // a production Drupal site. Burstable (B series) is cheaper for low-traffic
    // periods but may be inadequate under sustained load — adjust as needed.
    name: 'Standard_D2ds_v4'
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: '8.4'
    storage: {
      storageSizeGB: 20
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: delegatedSubnetId
      privateDnsZoneResourceId: privateDnsZone.id
    }
  }
  dependsOn: [dnsZoneVnetLink]
}

resource drupalDatabase 'Microsoft.DBforMySQL/flexibleServers/databases@2023-12-30' = {
  parent: mysqlServer
  name: 'drupal'
  properties: {
    charset: 'utf8mb4'
    collation: 'utf8mb4_unicode_ci'
  }
}

output fqdn string = mysqlServer.properties.fullyQualifiedDomainName
output serverName string = mysqlServer.name