#!/bin/bash
# Build ocpinventory.json from QUADS API, check for r630 models,
# and ensure bastion is powered on.
#
# Usage: ./check-r630.sh <lab> <cloud_name> [quads_server]
# Returns: "r630" and exit 0 if r630 found, "none" and exit 1 otherwise
# Side effect: saves built inventory to vars/<cloud_name>_ocpinventory.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETLAG_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Use yq from the jetlag venv
YQ="${JETLAG_ROOT}/.ansible/bin/yq"
if [[ ! -x "$YQ" ]]; then
    echo "Error: yq not found at $YQ. Run 'source bootstrap.sh' from the jetlag root first." >&2
    exit 2
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
    QUADS_HOST=$($YQ -r ".labs.${LAB}.quads" "$LAB_YML")
    if [[ -z "$QUADS_HOST" || "$QUADS_HOST" == "null" ]]; then
        echo "Error: Could not find QUADS server for lab '$LAB' in $LAB_YML" >&2
        exit 2
    fi
fi

# Build ocpinventory.json from QUADS API
QUADS_API="https://${QUADS_HOST}/api/v3"
MAX_RETRIES=90
RETRY_INTERVAL=10

# Get cloud_id
CLOUD_ID=$(curl -s "$QUADS_API/clouds?name=$CLOUD_NAME" | jq -r '.[0].id')
if [[ -z "$CLOUD_ID" || "$CLOUD_ID" == "null" ]]; then
    echo "Error: Could not find cloud_id for $CLOUD_NAME" >&2
    exit 2
fi

# Get pm_password from active assignment ticket
TICKET=$(curl -s "$QUADS_API/assignments?active=true&cloud_id=$CLOUD_ID" | jq -r '.[0].ticket')
if [[ -z "$TICKET" || "$TICKET" == "null" ]]; then
    echo "Error: Could not find active assignment ticket for $CLOUD_NAME" >&2
    exit 2
fi
PM_PASSWORD="rdu2@${TICKET}"

# Get host list, retrying until hosts are assigned
for ((i=1; i<=MAX_RETRIES; i++)); do
    HOST_LIST=$(curl -s "$QUADS_API/hosts?cloud_id=$CLOUD_ID" | jq -r '.[].name')
    if [[ -n "$HOST_LIST" ]]; then
        break
    fi
    if [[ $i -eq $MAX_RETRIES ]]; then
        echo "Error: No hosts found for $CLOUD_NAME after $MAX_RETRIES attempts" >&2
        exit 2
    fi
    echo "Waiting for hosts to be assigned... (attempt $i/$MAX_RETRIES)" >&2
    sleep "$RETRY_INTERVAL"
done

# Build inventory JSON from host data
NODES="[]"
for HOST in $HOST_LIST; do
    echo "Fetching MAC addresses for $HOST..." >&2
    MACS=$(curl -s "$QUADS_API/hosts/$HOST" | jq '[.interfaces | sort_by(.name) | .[].mac_address]')
    NODE=$(jq -n \
        --arg name "$HOST" \
        --arg pm_addr "mgmt-$HOST" \
        --arg pm_password "$PM_PASSWORD" \
        --argjson macs "$MACS" \
        '{
            arch: "x86_64",
            cpu: "2",
            disk: "20",
            mac: $macs,
            memory: "1024",
            name: $name,
            pm_addr: $pm_addr,
            pm_password: $pm_password,
            pm_type: "pxe_ipmitool",
            pm_user: "quads"
        }')
    NODES=$(echo "$NODES" | jq ". + [$NODE]")
done

INVENTORY_JSON=$(jq -n --argjson nodes "$NODES" '{nodes: $nodes}')

# Save inventory to file for reuse by create-inventory.yml
INVENTORY_FILE="${SCRIPT_DIR}/vars/${CLOUD_NAME}_ocpinventory.json"
mkdir -p "${SCRIPT_DIR}/vars"
echo "$INVENTORY_JSON" > "$INVENTORY_FILE"
echo "Inventory saved to $INVENTORY_FILE" >&2

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
