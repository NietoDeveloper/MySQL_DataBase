#!/usr/bin/env bash
# DANGER: drops and recreates the target database, then re-applies all
# migrations from scratch.
set -euo pipefail

: "${MYSQL_HOST:?Set MYSQL_HOST}"
: "${MYSQL_PORT:?Set MYSQL_PORT}"
: "${MYSQL_USER:?Set MYSQL_USER (bootstrap/admin account)}"
: "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD}"


read -p "This will DROP all data in '$MYSQL_DATABASE'. Type 'yes' to continue: " confirm
if [ "$co