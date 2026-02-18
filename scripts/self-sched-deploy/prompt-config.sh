#!/bin/bash
# Interactive configuration prompts for jetlag self-sched-deploy
# This script collects user input and outputs vars/config.env
#
# Usage: prompt-config.sh [mode]
#   mode: quads   - Only QUADS-related prompts (for create-assignment)
#         jetlag  - Only jetlag-related prompts (for inventory)
#         all     - All prompts (default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETLAG_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
mkdir -p "${SCRIPT_DIR}/vars"
CONFIG_FILE="${SCRIPT_DIR}/vars/config.env"

# Activate venv to access yq
if [[ -f "${JETLAG_ROOT}/.ansible/bin/activate" ]]; then
    source "${JETLAG_ROOT}/.ansible/bin/activate"
fi
STATE_FILE="${SCRIPT_DIR}/vars/state.env"

# Mode parameter
MODE="${1:-all}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=============================================${NC}"
}

print_info() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Prompt with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local is_password="${4:-false}"

    if [[ "$is_password" == "true" ]]; then
        read -r -s -p "$prompt [$default]: " value
        echo ""
    else
        read -r -p "$prompt [$default]: " value
    fi

    value="${value:-$default}"
    eval "$var_name='$value'"
}

# Prompt with options
prompt_with_options() {
    local prompt="$1"
    local options="$2"
    local default="$3"
    local var_name="$4"

    echo "$prompt"
    echo "Options: $options"
    read -r -p "Enter choice [$default]: " value
    value="${value:-$default}"
    eval "$var_name='$value'"
}

# Check for existing state
check_existing_state() {
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$STATE_FILE"
        if [[ -n "$CLOUD_NAME" ]]; then
            print_warning "Found existing assignment: $CLOUD_NAME"
            read -r -p "Use existing assignment? (y/n) [y]: " use_existing
            use_existing="${use_existing:-y}"
            if [[ "$use_existing" =~ ^[Yy] ]]; then
                export USE_EXISTING_ASSIGNMENT="true"
                return 0
            fi
        fi
    fi
    export USE_EXISTING_ASSIGNMENT="false"
    return 0
}

# Load existing config if present
load_existing_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

# QUADS-related prompts (for create-assignment)
collect_quads_config() {
    print_header "Lab Configuration"

    prompt_with_options "Select Lab" "scalelab, performancelab" "${LAB:-scalelab}" LAB

    # Auto-configure QUADS API server based on lab (from ansible/vars/lab.yml)
    LAB_YML="${JETLAG_ROOT}/ansible/vars/lab.yml"
    QUADS_API_SERVER=$(yq -r ".labs.${LAB}.quads" "$LAB_YML")
    if [[ -z "$QUADS_API_SERVER" || "$QUADS_API_SERVER" == "null" ]]; then
        print_error "Error: Could not find QUADS server for lab '$LAB' in $LAB_YML"
        exit 1
    fi
    print_info "QUADS Server: $QUADS_API_SERVER"

    print_header "QUADS Credentials"

    prompt_with_default "QUADS Username (without domain)" "${QUADS_USERNAME:-}" QUADS_USERNAME
    prompt_with_default "QUADS User Domain" "${QUADS_USER_DOMAIN:-redhat.com}" QUADS_USER_DOMAIN
    prompt_with_default "QUADS Password" "" QUADS_PASSWORD true

    print_header "Cluster Configuration"

    prompt_with_options "Cluster Type" "mno (Multi-Node), sno (Single-Node)" "${CLUSTER_TYPE:-mno}" CLUSTER_TYPE

    if [[ "$CLUSTER_TYPE" == "mno" ]]; then
        prompt_with_default "Worker Node Count" "${WORKER_NODE_COUNT:-2}" WORKER_NODE_COUNT
        # Auto-calculate hosts: 1 bastion + 3 controlplane + workers
        NUM_HOSTS=$((1 + 3 + WORKER_NODE_COUNT))
    else
        WORKER_NODE_COUNT=0
        # SNO: 1 bastion + 1 SNO node
        NUM_HOSTS=2
    fi

    print_info "Auto-calculated hosts to reserve: $NUM_HOSTS"
    prompt_with_default "Number of hosts to reserve (override if needed)" "$NUM_HOSTS" NUM_HOSTS

    print_header "Workload Description"

    prompt_with_default "Workload description for QUADS" "${WORKLOAD_NAME:-OCP ${CLUSTER_TYPE} cluster}" WORKLOAD_NAME
}

# Jetlag-related prompts (for inventory)
collect_jetlag_config() {
    print_header "OCP Configuration"

    prompt_with_options "OCP Build Type" "ga, dev, ci" "${OCP_BUILD:-ga}" OCP_BUILD

    case "$OCP_BUILD" in
        ga)
            default_version="latest-4.20"
            echo "For GA builds: latest-4.20, 4.20.1, latest-4.19, 4.19.5, etc."
            ;;
        dev)
            default_version="candidate-4.20"
            echo "For dev builds: candidate-4.20, candidate-4.19, latest"
            ;;
        ci)
            default_version="4.20.0-0.nightly-2025-02-25-035256"
            echo "For CI builds: 4.20.0-0.nightly-YYYY-MM-DD-HHMMSS"
            ;;
    esac
    prompt_with_default "OCP Version" "${OCP_VERSION:-$default_version}" OCP_VERSION

    print_header "Network Configuration"

    echo "1) ipv4  - IPv4 single-stack"
    echo "2) ipv6  - IPv6 single-stack"
    echo "3) dual  - Dual-stack (IPv4 + IPv6)"
    prompt_with_options "Select Network Stack" "ipv4, ipv6, dual" "${NETWORK_STACK:-ipv4}" NETWORK_STACK

    # Normalize network stack input
    case "$NETWORK_STACK" in
        1|ipv4) NETWORK_STACK="ipv4" ;;
        2|ipv6) NETWORK_STACK="ipv6" ;;
        3|dual) NETWORK_STACK="dual" ;;
    esac

    # IPv6 connectivity mode
    if [[ "$NETWORK_STACK" == "ipv6" ]]; then
        echo ""
        echo "IPv6 connectivity mode:"
        echo "1) proxy        - Connected via forward proxy (Squid on bastion)"
        echo "2) disconnected - Disconnected with local mirror registry"
        prompt_with_options "Select IPv6 mode" "proxy, disconnected" "${IPV6_MODE:-proxy}" IPV6_MODE

        # Normalize input
        case "$IPV6_MODE" in
            1|proxy) IPV6_MODE="proxy" ;;
            2|disconnected) IPV6_MODE="disconnected" ;;
        esac
    fi

    print_header "Pull Secret"

    # Default pull secret path is in jetlag root
    local default_pull_secret="${PULL_SECRET_PATH:-${JETLAG_ROOT}/pull-secret.txt}"
    prompt_with_default "Path to pull-secret.txt" "$default_pull_secret" PULL_SECRET_PATH

    # Validate pull secret exists
    if [[ ! -f "$PULL_SECRET_PATH" ]]; then
        print_error "Warning: Pull secret file not found at $PULL_SECRET_PATH"
        print_error "Please ensure the file exists before running deployment."
    fi

    print_header "Bastion SSH Access"

    echo "Enter the root password for the bastion host to copy your SSH key."
    prompt_with_default "Bastion root password" "" BASTION_ROOT_PASSWORD true

    # Set deploy playbook based on cluster type
    if [[ "$CLUSTER_TYPE" == "mno" ]]; then
        DEPLOY_PLAYBOOK="mno-deploy.yml"
    else
        DEPLOY_PLAYBOOK="sno-deploy.yml"
    fi
}

# Save configuration to file
save_config() {
    print_header "Saving Configuration"

    cat > "$CONFIG_FILE" << EOF
# Generated configuration - $(date)
# Do not edit manually - regenerated on each run

# QUADS Configuration
QUADS_API_SERVER="${QUADS_API_SERVER}"
QUADS_USERNAME="${QUADS_USERNAME}"
QUADS_USER_DOMAIN="${QUADS_USER_DOMAIN}"
QUADS_PASSWORD="${QUADS_PASSWORD}"

# Lab Configuration
LAB="${LAB}"

# OCP Configuration
OCP_BUILD="${OCP_BUILD}"
OCP_VERSION="${OCP_VERSION}"

# Cluster Configuration
CLUSTER_TYPE="${CLUSTER_TYPE}"
WORKER_NODE_COUNT="${WORKER_NODE_COUNT}"
NUM_HOSTS="${NUM_HOSTS}"
DEPLOY_PLAYBOOK="${DEPLOY_PLAYBOOK}"

# Network Configuration
NETWORK_STACK="${NETWORK_STACK}"
IPV6_MODE="${IPV6_MODE}"

# Paths
PULL_SECRET_PATH="${PULL_SECRET_PATH}"
JETLAG_ROOT="${JETLAG_ROOT}"

# Bastion SSH Access
BASTION_ROOT_PASSWORD="${BASTION_ROOT_PASSWORD}"

# Workload
WORKLOAD_NAME="${WORKLOAD_NAME}"

# State flags
USE_EXISTING_ASSIGNMENT="${USE_EXISTING_ASSIGNMENT}"
EOF

    # Load cloud name from state if using existing assignment
    if [[ "$USE_EXISTING_ASSIGNMENT" == "true" && -f "$STATE_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$STATE_FILE"
        {
            echo ""
            echo "# From existing state"
            echo "CLOUD_NAME=\"${CLOUD_NAME}\""
        } >> "$CONFIG_FILE"
    fi

    chmod 600 "$CONFIG_FILE"
    print_info "Configuration saved to $CONFIG_FILE"
}

# Display summary for QUADS mode
display_quads_summary() {
    print_header "Configuration Summary"

    echo "QUADS Server:     $QUADS_API_SERVER"
    echo "QUADS User:       $QUADS_USERNAME@$QUADS_USER_DOMAIN"
    echo "Lab:              $LAB"
    echo "Cluster Type:     $CLUSTER_TYPE"
    echo "Worker Nodes:     $WORKER_NODE_COUNT"
    echo "Hosts to Reserve: $NUM_HOSTS"
    echo "Workload:         $WORKLOAD_NAME"

    if [[ "$USE_EXISTING_ASSIGNMENT" == "true" ]]; then
        echo ""
        print_warning "Using existing assignment: $CLOUD_NAME"
    fi

    echo ""
    read -r -p "Proceed with this configuration? (y/n) [y]: " confirm
    confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_error "Configuration cancelled."
        exit 1
    fi
}

# Display summary for jetlag mode
display_jetlag_summary() {
    print_header "Configuration Summary"

    echo "OCP Build:        $OCP_BUILD"
    echo "OCP Version:      $OCP_VERSION"
    echo "Network Stack:    $NETWORK_STACK"
    if [[ "$NETWORK_STACK" == "ipv6" ]]; then
        echo "IPv6 Mode:        $IPV6_MODE"
    fi
    echo "Pull Secret:      $PULL_SECRET_PATH"
    if [[ -n "$BASTION_ROOT_PASSWORD" ]]; then
        echo "Bastion Password: (provided)"
    else
        echo "Bastion Password: (not provided - SSH key copy will be skipped)"
    fi

    echo ""
    read -r -p "Proceed with this configuration? (y/n) [y]: " confirm
    confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_error "Configuration cancelled."
        exit 1
    fi
}

# Display full summary
display_full_summary() {
    print_header "Configuration Summary"

    echo "QUADS Server:     $QUADS_API_SERVER"
    echo "QUADS User:       $QUADS_USERNAME@$QUADS_USER_DOMAIN"
    echo "Lab:              $LAB"
    echo "OCP Build:        $OCP_BUILD"
    echo "OCP Version:      $OCP_VERSION"
    echo "Cluster Type:     $CLUSTER_TYPE"
    echo "Worker Nodes:     $WORKER_NODE_COUNT"
    echo "Hosts to Reserve: $NUM_HOSTS"
    echo "Network Stack:    $NETWORK_STACK"
    if [[ "$NETWORK_STACK" == "ipv6" ]]; then
        echo "IPv6 Mode:        $IPV6_MODE"
    fi
    echo "Pull Secret:      $PULL_SECRET_PATH"
    echo "Workload:         $WORKLOAD_NAME"
    if [[ -n "$BASTION_ROOT_PASSWORD" ]]; then
        echo "Bastion Password: (provided)"
    else
        echo "Bastion Password: (not provided)"
    fi

    if [[ "$USE_EXISTING_ASSIGNMENT" == "true" ]]; then
        echo ""
        print_warning "Using existing assignment: $CLOUD_NAME"
    fi

    echo ""
    read -r -p "Proceed with this configuration? (y/n) [y]: " confirm
    confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_error "Configuration cancelled."
        exit 1
    fi
}

# Main
main() {
    case "$MODE" in
        quads)
            check_existing_state
            load_existing_config
            collect_quads_config
            display_quads_summary
            save_config
            ;;
        jetlag)
            load_existing_config
            collect_jetlag_config
            display_jetlag_summary
            save_config
            ;;
        all|*)
            check_existing_state
            load_existing_config
            collect_quads_config
            collect_jetlag_config
            display_full_summary
            save_config
            ;;
    esac
    print_info "Configuration complete!"
}

main "$@"
