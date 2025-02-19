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

validate_env_var "RELAYS"
validate_env_var "ALLOWED_EVENTS"

parse_pubkey_string() {
  input_str="$1"

  input_str="${input_str#[}"
  input_str="${input_str%]}"

  declare -a parsed_array=()

  IFS=',' read -ra ADDR <<< "$input_str"
  for i in "${ADDR[@]}"; do
    # Trim leading and trailing whitespace and quotes
    trimmed=$(echo "$i" | xargs)

    # Add escaped quotes around the pubkey
    quoted="\"$trimmed\""

    parsed_array+=("$quoted")
  done

  parsed_str=$(IFS=,; echo "${parsed_array[*]}")

  # Add leading and trailing square brackets
  parsed_str="[$parsed_str]"

  echo "$parsed_str"
}

FILTER="{\"kinds\":${ALLOWED_EVENTS}}"

sync_with_relay() {
    local relay=$1
    log "Started sync with ${relay}"
    ./strfry sync "${relay}" --filter=$FILTER  || {
        log "Sync with ${relay} failed. Exiting."
        exit 1
    }
    if [[ ! -z "$WHITELIST_PUBKEYS" ]]; then
        parsed_pubkeys=$(parse_pubkey_string "$WHITELIST_PUBKEYS")
        log "Started sync whitelist pubkeys events."
        ./strfry sync "${relay}" --filter="{\"authors\":${parsed_pubkeys}}" || {
            log "Sync of whitelist pubkeys events failed. Exiting."
            exit 1
        }
    fi
    log "Completed sync with ${relay}"
}

parse_and_sync_relays() {
    local cleaned_relays=${RELAYS//\[/}
    cleaned_relays=${cleaned_relays//\]/}

    IFS=',' read -ra ADDR <<< "$cleaned_relays"

    for i in "${ADDR[@]}"; do
        # Trim leading and trailing whitespace
        relay=$(echo "$i" | xargs)
        sync_with_relay "$relay"
    done
}

if [[ ! -x "./strfry" ]]; then
    log "strfry is either missing or not executable. Exiting."
    exit 1
fi

# Perform sync
parse_and_sync_relays
