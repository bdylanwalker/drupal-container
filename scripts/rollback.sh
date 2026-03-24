#!/usr/bin/env bash
# Roll back production to a previous ACA revision (code rollback).
#
# Usage:
#   ./scripts/rollback.sh <revision-name>   # roll back to a specific revision
#   ./scripts/rollback.sh                   # list available revisions
#
# -----------------------------------------------------------------------
# WHEN TO USE THIS SCRIPT
# -----------------------------------------------------------------------
# Use this for a code rollback when the new revision has a bug but the
# database migrations were backwards-compatible (the common case for
# patch/minor Drupal releases deployed via blue/green).
#
# The old revision is deactivated but NOT deleted after a blue/green
# deploy — it can be reactivated at any time.
#
# -----------------------------------------------------------------------
# DB ROLLBACK (breaking migrations)
# -----------------------------------------------------------------------
# If drush deploy ran destructive schema changes that the old code cannot
# work with, you also need to restore the database. Each pipeline run
# creates an on-demand backup named "pre-deploy-<BuildId>" immediately
# before drush deploy runs. Restore it via Azure PITR:
#
#   az mysql flexible-server restore \
#     --resource-group drupal-prod-rg \
#     --name drupal-mysql-restored \
#     --source-server <original-server-name> \
#     --restore-time <ISO-8601-timestamp-before-migration>
#
# Or use the Azure Portal: MySQL Flexible Server → Restore.
# After restore, update DB_HOST in the Container App to the new server.
#
# WARNING: PITR restores to a point in time — all data written after that
# point (including user content) will be lost.
#
# The "pre-deploy-<BuildId>" backup name is recorded in the
# "rollback-info" artifact on the ADO pipeline run.
# -----------------------------------------------------------------------

set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-drupal-prod-rg}"
APP_NAME="drupal"

if [[ -z "${1:-}" ]]; then
  echo "Available revisions (most recent first):"
  az containerapp revision list \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "reverse(sort_by([].{Name:name, Active:properties.active, State:properties.runningState, Traffic:properties.trafficWeight, Created:properties.createdTime}, &Created))" \
    --output table
  echo ""
  echo "Usage: $0 <revision-name>"
  exit 0
fi

TARGET_REVISION="$1"

echo "Rolling back to revision: $TARGET_REVISION"

echo "Activating revision..."
az containerapp revision activate \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision "$TARGET_REVISION"

echo "Cutting traffic to $TARGET_REVISION..."
az containerapp ingress traffic set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision-weight "$TARGET_REVISION=100"

echo ""
echo "Done. $TARGET_REVISION is now receiving 100% of traffic."
echo ""
echo "If the migration was breaking and you also need a DB rollback, the"
echo "pre-deploy snapshot name is recorded in the 'rollback-info' artifact"
echo "on the ADO pipeline run that deployed the broken version."