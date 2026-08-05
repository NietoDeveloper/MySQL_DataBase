#!/usr/bin/env bash
# DANGER: drops and recreates the target database, then re-applies all
# migrations from scratch.
set -euo pipefail

 "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD}"

read -p "This will DROP all data in '$MYSQL_DATABASE'. Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."


mysql --host="$MYSQL_HOST" --port="$MYSQL_PORT" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" \
      -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

"$(dirname "${BASH_SOURCE[0]}")/init.sh"
