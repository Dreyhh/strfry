#!/bin/bash

set -e
set -o pipefail

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Check if gcloud and gsutil are installed
if ! command -v gcloud &> /dev/null || ! command -v gsutil &> /dev/null; then
    log "Google Cloud SDK or gsutil is not installed. Exiting."
    exit 1
fi

currentdate=$(date +"%Y-%m-%d_%H-%M-%S")
cd /app

# Create the backup
./strfry export > "backup${currentdate}.jsonl" || {
    log "Backup creation failed. Exiting."
    exit 1
}

FILE_NAME="backup${currentdate}.jsonl"
LATEST_BACKUP="backup_latest.jsonl"

[[ -z "$BUCKET_NAME" ]] && {
    log "Bucket name is empty. Exiting."
    exit 1
}

[[ -z "$POD_NAME" ]] && {
    log "POD_NAME not set. Exiting."
    exit 1
}

# Compare the latest backup file with the newly generated one
if [[ -f "$LATEST_BACKUP" ]]; then
    if diff "$FILE_NAME" "$LATEST_BACKUP" &>/dev/null; then
        log "No changes detected. Exiting."
        rm -f "$FILE_NAME"
        exit 0
    fi
fi

# Upload the file to the GCS bucket if different or if latest backup doesn't exist
if gsutil cp "$FILE_NAME" "gs://${BUCKET_NAME}/${POD_NAME}/${POD_NAME}_${FILE_NAME}" ; then
    log "File ${FILE_NAME} has been successfully uploaded to ${BUCKET_NAME}."

    # Update latest backup and remove the original file
    mv -f "$FILE_NAME" "$LATEST_BACKUP"
    log "Local file ${FILE_NAME} has been moved to ${LATEST_BACKUP}."
else
    log "File upload failed. Exiting."
    exit 1
fi
