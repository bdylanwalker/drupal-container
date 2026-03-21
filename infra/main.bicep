targetScope = 'resourceGroup'

@description('Short name used as a prefix for all resources.')
param appName string = 'drupal'

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Docker image tag to deploy (passed from the pipeline as Build.BuildId).')
param imageTag string

@description('Name of the Azure Container Registry (must be globally unique).')
param acrName string

@description('MySQL administrator login name.')
param mysqlAdminLogin string = 'mysqladmin'

@secure()
@description('MySQL administrator password.')
param mysqlAdminPassword string

@secure()
@description('Drupal hash salt. Generate with: drush php-eval "echo \\Drupal\\Component\\Utility\\Crypt::randomBytesBase64(55);"')
param drupalHashSalt string

@description('Comma-separated trusted_host_patterns regex strings. Set to your Container App FQDN after first deploy.')
param drupalTrustedHostPatterns string = ''

// ---------------------------------------------------------------------------
// Shared user-assigned managed identity for ACR pulls.
//
// Using a user-assigned identity (rather than system-assigned) solves the
// RBAC propagation race: we create the identity, assign AcrPull on the ACR,
// and only then deploy the Container App and Job — so the permission is
// already in place when ACA first tries to pull the image.
// ---------------------------------------------------------------------------
resource containerAppsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${appName}-aca-identity'
  location: location
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    appName: appName
    location: location
  }
}

// ACR is deployed with the AcrPull role assignment for the identity above.
// aca-app and aca-job both dependsOn this module so the role is guaranteed
// to exist before either resource tries to pull an image.
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    acrName: acrName
    location: location
    containerAppsIdentityPrincipalId: containerAppsIdentity.properties.principalId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    appName: appName
    location: location
    vnetId: network.outputs.vnetId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
  }
}

module mysql 'modules/mysql.bicep' = {
  name: 'mysql'
  params: {
    appName: appName
    location: location
    administratorLogin: mysqlAdminLogin
    administratorPassword: mysqlAdminPassword
    delegatedSubnetId: network.outputs.mysqlSubnetId
    vnetId: network.outputs.vnetId
  }
}

module acaEnv 'modules/aca-environment.bicep' = {
  name: 'aca-environment'
  params: {
    appName: appName
    location: location
    acaSubnetId: network.outputs.acaSubnetId
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    fileShareName: storage.outputs.fileShareName
  }
}

var containerImage = '${acrName}.azurecr.io/drupal:${imageTag}'

module acaApp 'modules/aca-app.bicep' = {
  name: 'aca-app'
  params: {
    appName: appName
    location: location
    environmentId: acaEnv.outputs.environmentId
    containerImage: containerImage
    acrName: acrName
    identityResourceId: containerAppsIdentity.id
    mysqlHost: mysql.outputs.fqdn
    mysqlAdminLogin: mysqlAdminLogin
    mysqlAdminPassword: mysqlAdminPassword
    drupalHashSalt: drupalHashSalt
    drupalTrustedHostPatterns: drupalTrustedHostPatterns
  }
  dependsOn: [acr]
}

module acaJob 'modules/aca-job.bicep' = {
  name: 'aca-job'
  params: {
    appName: appName
    location: location
    environmentId: acaEnv.outputs.environmentId
    containerImage: containerImage
    acrName: acrName
    identityResourceId: containerAppsIdentity.id
    mysqlHost: mysql.outputs.fqdn
    mysqlAdminLogin: mysqlAdminLogin
    mysqlAdminPassword: mysqlAdminPassword
    drupalHashSalt: drupalHashSalt
  }
  dependsOn: [acr]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Public FQDN of the Drupal Container App.')
output appFqdn string = acaApp.outputs.fqdn

@description('Name of the drush deploy Container App Job (used in the pipeline).')
output drushJobName string = acaJob.outputs.jobName