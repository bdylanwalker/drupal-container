#!/bin/sh
set -e

# Ensure the public files directory exists.
# In production this path is overlaid by the Azure Files volume mount, so we
# create it here only as a safety net for local runs without the mount.
mkdir -p /var/www/html/web/sites/default/files

# Hand off to CMD (supervisord for web, drush for the deploy job)
exec "$@"