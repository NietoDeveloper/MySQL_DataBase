#!/usr/bin/env bash
# DANGER: drops and recreates the target database, then re-applies all
# migrations from scratch.
set -euo pipefail

 "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD}"
