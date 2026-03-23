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
param databaseName string = 'drupal'

// The job name is also hardcoded in azure-pipelines.yml — keep them in sync.
var jobName = '${appName}-drush-deploy'

resource drushJob 'Microsoft.App/jobs@2024-03-01' = {
  name: jobName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 600
      replicaRetryLimit: 0
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
          args: ['drush', 'deploy', '--yes']
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'DB_HOST',     value: mysqlHost }
            { name: 'DB_NAME',     value: databaseName }
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

output jobName string = drushJob.name