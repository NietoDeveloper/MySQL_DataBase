#!/usr/bin/env bash
# Creates (or rotates the password of) the least-privilege LOGIN account

set -euo pipefail

: "${MYSQL_HOST:?Set MYSQL_HOST}"
: "${MYSQL_PORT:?Set MYSQL_PORT}"
: "${MYSQL_USER:?Set MYSQL_USER (bootstrap/admin account)}"
: "${MYSQL_PASSWORD:?Set MYSRD to a strong, generated password for app_user}"

mysql --host="$MYSQL_HOST" --port="$MYSQL_PORT" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS 'app_user'@'%'
