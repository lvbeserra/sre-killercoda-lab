#!/usr/bin/env bash
# Prepara PostgreSQL local para os workers no Ubuntu/KillerCoda.
set -euo pipefail
if [ "$(id -u)" != 0 ]; then
  echo 'Execute como root no Ubuntu de laboratorio.' >&2
  exit 1
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apt-get update
apt-get install -y postgresql postgresql-client python3-venv
service postgresql start
pg_isready
if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='root'" | grep -qx 1; then
  runuser -u postgres -- createuser --no-superuser --no-createdb --no-createrole root
fi
if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='sre_curriculos'" | grep -qx 1; then
  runuser -u postgres -- createdb --owner=root sre_curriculos
fi
psql -d sre_curriculos -v ON_ERROR_STOP=1 -f "$script_dir/schema.sql"
echo 'PostgreSQL da Aula 03 pronto: banco sre_curriculos, role root sem privilegios de superusuario.'
