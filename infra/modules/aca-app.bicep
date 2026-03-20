param appName string
param location string
param environmentId string
param containerImage string
param acrName string
param mysqlHost string
param mysqlAdminLogin string
@secure()
param mysqlAdminPassword string
@secure()
param drupalHashSalt string
param drupalTrustedHostPatterns string = ''

// Built-in role definition ID for AcrPull.
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ---------------------------------------------------------------------------
// Container App — system-assigned managed identity for ACR pull
// ---------------------------------------------------------------------------
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        // Allow insecure traffic — ACA ingress handles TLS termination.
        allowInsecure: false
      }
      // Use the managed identity to pull from ACR (no stored credentials).
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'db-password'
          value: mysqlAdminPassword
        }
        {
          name: 'drupal-hash-salt'
          value: drupalHashSalt
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
      volumes: [
        {
          name: 'drupal-files'
          storageType: 'AzureFile'
          storageName: 'drupal-files'
        }
      ]
      containers: [
        {
          name: appName
          image: containerImage
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            { name: 'DB_HOST',     value: mysqlHost }
            { name: 'DB_NAME',     value: 'drupal' }
            { name: 'DB_USER',     value: mysqlAdminLogin }
            { name: 'DB_PASSWORD', secretRef: 'db-password' }
            { name: 'DRUPAL_HASH_SALT', secretRef: 'drupal-hash-salt' }
            { name: 'DRUPAL_TRUSTED_HOST_PATTERNS', value: drupalTrustedHostPatterns }
            { name: 'DRUPAL_ENVIRONMENT', value: 'production' }
          ]
          volumeMounts: [
            {
              volumeName: 'drupal-files'
              mountPath: '/var/www/html/web/sites/default/files'
            }
          ]
        }
      ]
    }
  }
}

// Grant the Container App's managed identity the AcrPull role on the registry.
// Note: RBAC propagation can take 1-2 minutes; the first pull may retry briefly.
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerApp.id, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn