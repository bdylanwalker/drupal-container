#!/usr/bin/env bash
# Pull the production database to your local Drupal install.
#
# Usage:
#   ./scripts/db-pull.sh
#
# Prerequisites:
#   - az CLI logged in (az login)
#   - ddev running locally (or adjust the drush invocation below)
#   - Your IP is in the developerIps list in infra/main.parameters.json
#
# What it does:
#   1. Looks up the MySQL hostname and password from Azure
#   2. Exports PROD_DB_HOST and PROD_DB_PASSWORD for the @prod alias
#   3. Runs: drush sql:sync @prod @self
#
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-drupal-prod-rg}"

echo "Fetching MySQL hostname from Azure..."
PROD_DB_HOST=$(az mysql flexible-server list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[0].fullyQualifiedDomainName" \
  --output tsv)

if [[ -z "$PROD_DB_HOST" ]]; then
  echo "ERROR: Could not find MySQL server in resource group '$RESOURCE_GROUP'." >&2
  exit 1
fi
echo "  Host: $PROD_DB_HOST"

echo "Fetching MySQL password from Azure DevOps variable group..."
echo "  (You will be prompted if PROD_DB_PASSWORD is not already set in your environment.)"

if [[ -z "${PROD_DB_PASSWORD:-}" ]]; then
  read -rsp "MySQL admin password: " PROD_DB_PASSWORD
  echo
fi

export PROD_DB_HOST
export PROD_DB_PASSWORD

echo "Running drush sql:sync @prod @self ..."
# If using ddev, prefix with: ddev drush
# If using a local PHP install, just: drush
drush sql:sync @prod @self

echo "Done. Production database is now in your local environment."