#!/usr/bin/env bash
# Runs every migration in /migrations, in filename order, against the
# MySQL instance described by MYSQL_HOST / MYSQL_PORT / MYSQL_USER /
# MYSQL_PASSWORD / MYSQL_DATABASE (the mysql CLI has no equivalent of
# psql's single DATABASE_URL flag, so discrete vars are used instead).
set -euo pipefail

: "${MYSQL_HOST:?Set MYSQL_HOST}"
