#!/usr/bin/env bash
# Pull the production database into your local ddev environment.
#
# Usage:
#   ./scripts/db-pull.sh
#
# Prerequisites:
#   - az CLI logged in (az login)
#   - ddev running locally (ddev start)
#   - mysqldump installed on your Mac (brew install mysql-client)
#   - Your IP is in developerIps in infra/main.parameters.json
#
# What it does:
#   1. Looks up the MySQL hostname from Azure
#   2. Prompts for the MySQL password (or reads from PROD_DB_PASSWORD env var)
#   3. Runs mysqldump from your Mac directly against prod (--ssl-mode=REQUIRED)
#   4. Imports the dump into ddev with `ddev import-db`
#
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-drupal-prod-rg}"
DUMP_FILE="/tmp/drupal-prod-$(date +%Y%m%d_%H%M%S).sql.gz"

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

if [[ -z "${PROD_DB_PASSWORD:-}" ]]; then
  read -rsp "MySQL admin password: " PROD_DB_PASSWORD
  echo
fi

echo "Dumping production database..."
mysqldump \
  --host="$PROD_DB_HOST" \
  --user=mysqladmin \
  --password="$PROD_DB_PASSWORD" \
  --ssl-mode=REQUIRED \
  --no-tablespaces \
  --single-transaction \
  --no-autocommit \
  --opt \
  -Q \
  drupal \
  | gzip > "$DUMP_FILE"

echo "  Saved to $DUMP_FILE"

echo "Importing into ddev..."
ddev import-db --file="$DUMP_FILE"

rm -f "$DUMP_FILE"
echo "Done. Production database is now in your local ddev environment."