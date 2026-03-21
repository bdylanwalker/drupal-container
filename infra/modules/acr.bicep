param acrName string
param location string

@description('Principal ID of the user-assigned managed identity that needs AcrPull.')
param containerAppsIdentityPrincipalId string

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    // Standard supports up to 100 GB storage and is appropriate for production.
    // Upgrade to Premium if you need geo-replication or private endpoints on ACR.
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Grant AcrPull to the shared user-assigned identity BEFORE the Container App
// and Job are deployed. This avoids the RBAC propagation race that causes
// "Operation expired" when a system-assigned identity is used — there, the role
// assignment is created after the resource exists and ACA immediately tries to pull.
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerAppsIdentityPrincipalId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: containerAppsIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output loginServer string = acr.properties.loginServer
output registryId string = acr.id