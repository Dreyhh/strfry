#!/bin/bash

cd /app

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

validate_env_var() {
    local var_name=$1
    local var_value
    eval "var_value=\${$var_name}"
    if [[ -z "$var_value" ]]; then
        log "Environment variable ${var_name} is not set. Exiting."
        exit 1
    fi
}

validate_env_var "RELAY_A"
validate_env_var "RELAY_B"
validate_env_var "ALLOWED_EVENTS"

FILTER="{\"kinds\":${ALLOWED_EVENTS}}"

sync_with_relay() {
    local relay=$1
    log "Started sync with ${relay}"
    ./strfry sync "${relay}" --filter "${FILTER}" || {
        log "Sync with ${relay} failed. Exiting."
        exit 1
    }
    log "Completed sync with ${relay}"
}

if [[ ! -x "./strfry" ]]; then
    log "strfry is either missing or not executable. Exiting."
    exit 1
fi

# Perform sync
sync_with_relay "$RELAY_A"
sync_with_relay "$RELAY_B"
