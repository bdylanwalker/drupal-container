param appName string
param location string
param administratorLogin string
@secure()
param administratorPassword string

@description('IPv4 addresses allowed through the MySQL firewall (one rule per IP).')
param developerIps array = []

// Server name must be globally unique across Azure.
var serverName = '${appName}-mysql-${uniqueString(resourceGroup().id)}'

// ---------------------------------------------------------------------------
// MySQL 8.4 Flexible Server — public endpoint, firewall-restricted
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
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource drupalDatabase 'Microsoft.DBforMySQL/flexibleServers/databases@2023-12-30' = {
  parent: mysqlServer
  name: 'drupal'
  properties: {
    charset: 'utf8mb4'
    collation: 'utf8mb4_unicode_ci'
  }
}

// ---------------------------------------------------------------------------
// Firewall rules
// ---------------------------------------------------------------------------

// Azure convention: start/end both 0.0.0.0 means "allow all Azure services".
// This allows ACA (which uses Azure's shared outbound IPs) to reach MySQL.
resource allowAzureServices 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-30' = {
  parent: mysqlServer
  name: 'allow-azure-services'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// One rule per developer IP passed in via the developerIps parameter.
resource developerFirewallRules 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-30' = [for (ip, i) in developerIps: {
  parent: mysqlServer
  name: 'developer-${i}'
  properties: {
    startIpAddress: ip
    endIpAddress: ip
  }
}]

output fqdn string = mysqlServer.properties.fullyQualifiedDomainName
output serverName string = mysqlServer.name