#!/usr/bin/env bash
# DANGER: drops and recreates the target database, then re-applies all
# migrations from scratch.
set -euo pipefail

 "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD}"

read -p "This will DROP all data in '$MYSQL_DATABASE'. Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."