param appName string
param location string
param environmentId string
param containerImage string
param acrName string
param identityResourceId string
param mysqlHost string
param mysqlAdminLogin string
@secure()
param mysqlAdminPassword string
@secure()
param drupalHashSalt string
param drupalTrustedHostPatterns string = ''
param databaseName string = 'drupal'
param revisionSuffix string
param activeRevisionName string = ''

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  // User-assigned identity; AcrPull is granted before this resource is deployed
  // (see acr.bicep), eliminating the RBAC propagation race condition.
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
        traffic: empty(activeRevisionName) ? [
          {
            latestRevision: true
            weight: 100
          }
        ] : [
          {
            revisionName: activeRevisionName
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: identityResourceId
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
      revisionSuffix: take(revisionSuffix, 10)
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
            { name: 'DB_NAME',     value: databaseName }
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
          probes: [
            {
              // Readiness probe hits the nginx-only /healthz endpoint.
              // Using / would fail: Drupal returns 400 for requests whose
              // Host header doesn't match trusted_host_patterns, which is
              // always the case for internal probe traffic.
              type: 'Readiness'
              httpGet: {
                path: '/healthz'
                port: 80
              }
              initialDelaySeconds: 10
              periodSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn