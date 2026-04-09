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
MAX_RETRIES=90
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

# Check bastion power state and power on if needed (only when wipe is off)
if [[ "${WIPE_DISKS:-}" = "no" ]]; then
    BMC_ADDRESS=$(echo "$INVENTORY_JSON" | jq -r '.nodes[0].pm_addr')
    BMC_USER=$(echo "$INVENTORY_JSON" | jq -r '.nodes[0].pm_user')
    BMC_PASSWORD=$(echo "$INVENTORY_JSON" | jq -r '.nodes[0].pm_password')
    BASTION_HOST=$(echo "$INVENTORY_JSON" | jq -r '.nodes[0].name')

    echo "Checking power state of bastion ($BASTION_HOST) via Redfish..." >&2
    POWER_STATE=$(curl -s -k -u "$BMC_USER:$BMC_PASSWORD" \
        "https://$BMC_ADDRESS/redfish/v1/Systems/System.Embedded.1" | jq -r '.PowerState')

    if [[ "$POWER_STATE" != "On" ]]; then
        echo "Bastion is $POWER_STATE, powering on..." >&2
        curl -s -k -u "$BMC_USER:$BMC_PASSWORD" -X POST \
            -H "Content-Type: application/json" \
            -d '{"ResetType":"On"}' \
            "https://$BMC_ADDRESS/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset" >/dev/null

        echo "Waiting for bastion to become reachable via SSH..." >&2
        for ((j=1; j<=60; j++)); do
            SSH_OUTPUT=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null root@"$BASTION_HOST" true 2>&1 || true)
            if ! echo "$SSH_OUTPUT" | grep -q "Connection refused\|Connection timed out\|No route to host"; then
                echo "Bastion is reachable via SSH." >&2
                break
            fi
            if [[ $j -eq 60 ]]; then
                echo "Error: Bastion not reachable via SSH after 60 attempts" >&2
                exit 2
            fi
            echo "Waiting for SSH... (attempt $j/60)" >&2
            sleep 10
        done
    else
        echo "Bastion is already powered on." >&2
    fi
fi

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
