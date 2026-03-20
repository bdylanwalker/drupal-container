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

// The job name is also hardcoded in azure-pipelines.yml — keep them in sync.
var jobName = '${appName}-drush-deploy'

// Built-in role definition ID for AcrPull.
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ---------------------------------------------------------------------------
// Container App Job — runs `drush deploy` once per pipeline invocation.
// triggerType: Manual means it only runs when explicitly started (never on a
// schedule and never automatically on image update).
// ---------------------------------------------------------------------------
resource drushJob 'Microsoft.App/jobs@2024-03-01' = {
  name: jobName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 600  // 10 minutes; drush deploy should never take longer.
      replicaRetryLimit: 0 // Do not retry on failure — fail fast and fix forward.
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
      manualTriggerConfig: {
        replicaCompletionCount: 1
        parallelism: 1
      }
    }
    template: {
      volumes: [
        {
          name: 'drupal-files'
          storageType: 'AzureFile'
          storageName: 'drupal-files'
        }
      ]
      containers: [
        {
          name: 'drush-deploy'
          image: containerImage
          // Override CMD; ENTRYPOINT (/entrypoint.sh) still runs first via exec "$@".
          args: ['drush', 'deploy', '--yes']
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'DB_HOST',     value: mysqlHost }
            { name: 'DB_NAME',     value: 'drupal' }
            { name: 'DB_USER',     value: mysqlAdminLogin }
            { name: 'DB_PASSWORD', secretRef: 'db-password' }
            { name: 'DRUPAL_HASH_SALT', secretRef: 'drupal-hash-salt' }
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

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, drushJob.id, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: drushJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output jobName string = drushJob.name