#!/usr/bin/env bash
# Entrada única após o clone do repositório.
set -euo pipefail
cd "$(dirname "$0")"
exec bash sre-killercoda-lab/setup.sh
