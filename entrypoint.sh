#!/bin/bash

if ! pgrep -x "cron" > /dev/null; then
    # Start the cron in the background
    cron &
fi
# Init cron jobs
/app/init_cronjobs.sh
# Run the relay
/app/strfry relay

