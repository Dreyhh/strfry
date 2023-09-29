#!/bin/bash
. ~/.bashrc
# Read each line from backup.conf
while IFS= read -r line; do
  # Skip empty lines and lines starting with a comment
  [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

  # Export the variable. Use eval to handle values with quotes correctly.
  eval "export $line"
done < /etc/backup.conf
