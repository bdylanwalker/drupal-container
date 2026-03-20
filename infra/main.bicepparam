using './main.bicep'

// ---------------------------------------------------------------------------
// Non-secret parameters — commit this file.
// Secrets (mysqlAdminPassword, drupalHashSalt) are passed from the pipeline
// as secret variables and must NOT appear here.
// imageTag is also passed from the pipeline (Build.BuildId).
// ---------------------------------------------------------------------------

param appName = 'drupal'

// acrName must be globally unique across all of Azure (alphanumeric, 5-50 chars).
param acrName = 'drupalacr'

param mysqlAdminLogin = 'mysqladmin'

// Set this after the first deploy once you know the Container App FQDN.
// Example: '^drupal\\.azurecontainerapps\\.io$'
param drupalTrustedHostPatterns = ''