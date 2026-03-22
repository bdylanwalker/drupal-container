<?php

/**
 * @file
 * Drupal 11 settings for containerized Azure deployment.
 *
 * In production, all environment-specific values are injected via Azure
 * Container App environment variables and secrets.
 *
 * Locally, copy .env.example to .env at the project root and fill in values.
 * The .env file is loaded below via phpdotenv before any getenv() calls.
 *
 * Required environment variables:
 *   DB_HOST             — MySQL Flexible Server FQDN
 *   DB_NAME             — Database name (default: drupal)
 *   DB_USER             — Database username
 *   DB_PASSWORD         — Database password
 *   DRUPAL_HASH_SALT    — Unique hash salt
 *
 * Optional environment variables:
 *   DB_PORT                      — MySQL port (default: 3306)
 *   DRUPAL_TRUSTED_HOST_PATTERNS — Comma-separated regex patterns for trusted hosts
 *   DRUPAL_ENVIRONMENT           — Environment name (default: production)
 */

// ---------------------------------------------------------------------------
// Load .env for local development.
// In production there is no .env file; env vars come from the Container App.
// createImmutable() will not override variables already set in the environment.
// ---------------------------------------------------------------------------
$_envFile = dirname($app_root) . '/.env';
if (file_exists($_envFile) && class_exists(\Dotenv\Dotenv::class)) {
  \Dotenv\Dotenv::createImmutable(dirname($app_root))->safeLoad();
}
unset($_envFile);

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
$databases['default']['default'] = [
  'database'  => getenv('DB_NAME') ?: 'drupal',
  'username'  => getenv('DB_USER') ?: 'drupal',
  'password'  => getenv('DB_PASSWORD'),
  'host'      => getenv('DB_HOST'),
  'port'      => getenv('DB_PORT') ?: '3306',
  'prefix'    => '',
  'driver'    => 'mysql',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'autoload'  => 'core/modules/mysql/src/Driver/Database/mysql/',
  'isolation_level' => 'READ COMMITTED',
  'pdo' => [
    \PDO::MYSQL_ATTR_SSL_CA                => '/etc/ssl/certs/mysql-azure.pem',
    \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => FALSE,
  ],
];

// ---------------------------------------------------------------------------
// Security
// ---------------------------------------------------------------------------
$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT');
$settings['update_free_access'] = FALSE;
$settings['allow_authorize_operations'] = FALSE;

// Trusted host patterns.
// Set DRUPAL_TRUSTED_HOST_PATTERNS to a comma-separated list of regex patterns.
// Example: "^mysite\.azurecontainerapps\.io$,^www\.example\.com$"
// After first deploy, set this to your Container App FQDN pattern.
if ($trustedPatterns = getenv('DRUPAL_TRUSTED_HOST_PATTERNS')) {
  $settings['trusted_host_patterns'] = array_filter(
    array_map('trim', explode(',', $trustedPatterns))
  );
}

// ---------------------------------------------------------------------------
// File system
// ---------------------------------------------------------------------------
// Public files are served from sites/default/files (Azure Files mount).
$settings['file_public_path'] = 'sites/default/files';

// Temporary file storage inside the container (ephemeral, not persisted).
$settings['file_temp_path'] = '/tmp';

// Store compiled Twig templates on the container's local filesystem.
// Azure Files SMB does not support chmod(), causing PHP warnings when Drupal
// tries to set permissions on the twig cache directory. Moving to /tmp keeps
// the cache local (ephemeral per-replica) and avoids the warnings entirely.
$settings['php_storage']['twig']['directory'] = '/tmp';
$settings['php_storage']['default']['directory'] = '/tmp';

// Config sync directory — maps to the config/sync/ directory at project root.
$settings['config_sync_directory'] = dirname($app_root) . '/config/sync';

// ---------------------------------------------------------------------------
// Performance (production defaults for immutable container images)
// ---------------------------------------------------------------------------
$settings['extension_discovery_scan_tests'] = FALSE;
$settings['rebuild_access'] = FALSE;

// CSS/JS aggregation requires chmod() on the public files directory.
// Azure Files SMB does not support chmod(), causing FileSystem::prepareDirectory()
// to return FALSE and preventing aggregated files from being written.
// TODO: re-enable once a custom module overrides file.system to suppress
// chmod failures on paths that are already accessible.
$config['system.performance']['css']['preprocess'] = FALSE;
$config['system.performance']['js']['preprocess'] = FALSE;

// ---------------------------------------------------------------------------
// Reverse proxy (Azure Container Apps load balancer)
// ---------------------------------------------------------------------------
// ACA terminates TLS at the ingress layer and forwards X-Forwarded-For.
// Enabling this lets Drupal see the real client IP and correct scheme.
$settings['reverse_proxy'] = TRUE;
$settings['reverse_proxy_addresses'] = ['127.0.0.1'];

// ---------------------------------------------------------------------------
// Local development overrides
// ---------------------------------------------------------------------------

// DDEV: settings.ddev.php is auto-generated by `ddev start` and gitignored.
// It injects the local database connection and other DDEV-specific config.
if (getenv('IS_DDEV_PROJECT') === 'true'
    && file_exists($app_root . '/' . $site_path . '/settings.ddev.php')) {
  include $app_root . '/' . $site_path . '/settings.ddev.php';
}

// settings.local.php is gitignored; copy settings.local.php.example to use
// for non-DDEV local overrides.
if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}

// Azure SSL overrides — baked into the Docker image at this path.
// Loaded last so it re-applies PDO SSL options even if the Drupal installer
// rewrote $databases above without them.
if (file_exists($app_root . '/' . $site_path . '/settings.azure.php')) {
  include $app_root . '/' . $site_path . '/settings.azure.php';
}