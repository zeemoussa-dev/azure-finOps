#!/usr/bin/env bash
# Deploys the FinOps Cost Management views as SHARED views using Azure CLI + jq.
# Usage:
#   ./deploy-finops-views.sh <scope> [costCenterTag] [appTag] [envTag] [budgetId]
# Example:
#   ./deploy-finops-views.sh /subscriptions/<subId> CostCenter Application Environment
set -euo pipefail

SCOPE="${1:?scope required, e.g. /subscriptions/<subId>}"
CC_TAG="${2:-CostCenter}"
APP_TAG="${3:-Application}"
ENV_TAG="${4:-Environment}"
BUDGET_ID="${5:-}"
API_VERSION="${API_VERSION:-2023-11-01}"
DIR="$(cd "$(dirname "$0")" && pwd)/views"
SCOPE="${SCOPE%/}"

for f in "$DIR"/*.json; do
  name="$(basename "$f" .json)"
  body="$(sed -e "s/__COSTCENTER_TAG__/${CC_TAG}/g" \
              -e "s/__APP_TAG__/${APP_TAG}/g" \
              -e "s/__ENV_TAG__/${ENV_TAG}/g" "$f" |
          jq --arg b "$BUDGET_ID" '
            if $b == "" then .properties.kpis |= map(select(.type != "Budget"))
            else .properties.kpis |= map(if .type == "Budget" then .id = $b else . end) end')"

  if az rest --method put \
       --url "https://management.azure.com${SCOPE}/providers/Microsoft.CostManagement/views/${name}?api-version=${API_VERSION}" \
       --body "$body" --output none; then
    echo "  [OK]   $name"
  else
    echo "  [FAIL] $name"
  fi
done
