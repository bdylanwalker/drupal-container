param acrName string
param location string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    // Standard supports up to 100 GB storage and is appropriate for production.
    // Upgrade to Premium if you need geo-replication or private endpoints on ACR.
    name: 'Standard'
  }
  properties: {
    // Admin user is disabled; Container Apps authenticate via managed identity.
    adminUserEnabled: false
  }
}

output loginServer string = acr.properties.loginServer
output registryId string = acr.id