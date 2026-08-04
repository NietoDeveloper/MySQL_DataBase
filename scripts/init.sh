#!/usr/bin/env bash
# Runs every migration in /migrations, in filename order, against the
# MySQL instance described by MYSQL_HOST / MYSQL_PORT / MYSQL_USER /
# MYSQL_PASSWORD / MYSQ flag, so discrete vars are used instead).
set -euo pipefail

: "${MYSQL_HOST:?Set MYSQL_HOST}"
: 
