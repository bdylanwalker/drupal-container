param appName string
param location string
param storageAccountName string
@secure()
param storageAccountKey string
param fileShareName string

// The storage mount name is referenced by name in the Container App and Job volumes.
var storageMountName = 'drupal-files'

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${appName}-env'
  location: location
  properties: {
    zoneRedundant: false
  }
}

// Register the Azure Files share with the environment so Container Apps and
// Jobs can reference it by the storageMountName in their volume definitions.
resource environmentStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: storageMountName
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: fileShareName
      accessMode: 'ReadWrite'
    }
  }
}

output environmentId string = environment.id
output environmentName string = environment.name
output storageMountName string = storageMountName