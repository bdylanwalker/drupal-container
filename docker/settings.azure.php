<?php

/**
 * @file
 * Azure-specific database overrides — loaded after settings.php.
 *
 * This file is baked into the Docker image and is NOT overwritten by
 * Drupal's installer (which only rewrites web/sites/default/settings.php).
 * It re-applies PDO SSL options that the installer strips from $databases
 * when it rewrites settings.php during site:install.
 *
 * Azure MySQL 8.4 enforces require_secure_transport=ON.  PHP's mysqlnd
 * driver requires MYSQL_ATTR_SSL_VERIFY_SERVER_CERT to be set (either
 * true or false) to actually initiate SSL mode; setting only
 * MYSQL_ATTR_SSL_CA is insufficient with mysqlnd.
 */
$databases['default']['default']['pdo'] = [
  \PDO::MYSQL_ATTR_SSL_CA                => '/etc/ssl/certs/mysql-azure.pem',
  \PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => FALSE,
];