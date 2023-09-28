#!/bin/bash

LOG_FILE="/var/log/init_cron.log"

log() {
     echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

set_cron_job() {
    local schedule=$1
    local command=$2
    local log_file=$3

    if [[ -z "$schedule" || -z "$command" || -z "$log_file" ]]; then
        log "Missing arguments to set_cron_job function"
        exit 1
    fi

    # Create a temp file to hold the new cron jobs
    local temp_cron=$(mktemp)

    # Dump the existing cron jobs into the temp file
    crontab -l 2>/dev/null > "$temp_cron"

    # Remove existing job with the same command from the temp file (if exists)
    sed -i "\#$command#d" "$temp_cron"

    # Append the new job to the temp file
    echo "$schedule $command >> $log_file 2>&1" >> "$temp_cron"

    # Install the new cron jobs
    crontab "$temp_cron"

    # Remove the temp file
    rm -f "$temp_cron"
}

# Validate that the required variables are set
if [[ -z "$BACKUP_SCHEDULE" || -z "$SYNC_SCHEDULE" ]]; then
    log "BACKUP_SCHEDULE and SYNC_SCHEDULE must be set."
    exit 1
fi

# Set up the cron jobs
set_cron_job "$BACKUP_SCHEDULE" "/app/backup_script.sh" "/var/log/backup_script.log"
set_cron_job "$SYNC_SCHEDULE" "/app/sync_script.sh" "/var/log/sync_script.log"

log "Cron jobs initialized successfully."
