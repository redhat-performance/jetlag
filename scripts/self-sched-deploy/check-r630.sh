#!/bin/bash
# Check if allocated servers include r630 models
# Downloads ocpinventory.json from QUADS and parses pm_addr fields
#
# Usage: ./check-r630.sh <lab> <cloud_name> [quads_server]
# Returns: "r630" and exit 0 if r630 found, "none" and exit 1 otherwise

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETLAG_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Activate venv to access yq
if [[ -f "${JETLAG_ROOT}/.ansible/bin/activate" ]]; then
    source "${JETLAG_ROOT}/.ansible/bin/activate"
fi

LAB="${1:-scalelab}"
CLOUD_NAME="${2}"
QUADS_SERVER="${3}"

if [[ -z "$CLOUD_NAME" ]]; then
    echo "Usage: $0 <lab> <cloud_name> [quads_server]" >&2
    exit 2
fi

# Check for required dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 2
fi

# Use provided QUADS server or map from lab (from ansible/vars/lab.yml)
if [[ -n "$QUADS_SERVER" ]]; then
    QUADS_HOST="$QUADS_SERVER"
else
    LAB_YML="${JETLAG_ROOT}/ansible/vars/lab.yml"
    QUADS_HOST=$(yq -r ".labs.${LAB}.quads" "$LAB_YML")
    if [[ -z "$QUADS_HOST" || "$QUADS_HOST" == "null" ]]; then
        echo "Error: Could not find QUADS server for lab '$LAB' in $LAB_YML" >&2
        exit 2
    fi
fi

# Download ocpinventory.json, retrying until nodes data is available
INVENTORY_URL="http://${QUADS_HOST}/instack/${CLOUD_NAME}_ocpinventory.json"
MAX_RETRIES=12
RETRY_INTERVAL=10

for ((i=1; i<=MAX_RETRIES; i++)); do
    INVENTORY_JSON=$(curl -s "$INVENTORY_URL")
    if [[ -n "$INVENTORY_JSON" && "$INVENTORY_JSON" != "null" ]] && \
       echo "$INVENTORY_JSON" | jq -e '.nodes | length > 0' &>/dev/null; then
        break
    fi
    if [[ $i -eq $MAX_RETRIES ]]; then
        echo "Error: ocpinventory.json not available after $MAX_RETRIES attempts" >&2
        exit 2
    fi
    echo "Waiting for ocpinventory.json to be ready... (attempt $i/$MAX_RETRIES)" >&2
    sleep "$RETRY_INTERVAL"
done

# Extract server models from pm_addr fields
# Pattern: mgmt-[rack]-[unit]-[model].domain → extract [model]
MODELS=$(echo "$INVENTORY_JSON" | jq -r '.nodes[].pm_addr' | \
    sed 's/\..*//' | \
    sed 's/.*-//')

# Check for r630
if echo "$MODELS" | grep -q "^r630$"; then
    echo "r630"
    exit 0
fi

echo "none"
exit 1
