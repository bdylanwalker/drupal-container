param appName string
param location string

// Storage account names must be 3-24 lowercase alphanumeric characters.
var storageAccountName = take(
  toLower(replace('${appName}files${uniqueString(resourceGroup().id)}', '-', '')),
  24
)
var fileShareName = 'drupal-files'

// ---------------------------------------------------------------------------
// Storage account — public endpoint, key-authenticated
// ---------------------------------------------------------------------------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    // Explicitly allow all network access — previously this was Deny with a
    // private endpoint. ARM preserves existing networkAcls if omitted, so we
    // must set Allow explicitly to avoid mount errors after the PE was removed.
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

output storageAccountName string = storageAccount.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value
output fileShareName string = fileShareName