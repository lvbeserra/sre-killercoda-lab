#!/usr/bin/env bash
# AWS Emulator oficial - Ubuntu/Debian x86_64 - laboratorio KillerCoda
set -euo pipefail
test "$(dpkg --print-architecture)" = amd64 || { echo 'Requer Ubuntu/Debian amd64'; exit 1; }
if [ "$(id -u)" = 0 ]; then
  apt-get update
  apt-get install -y curl ca-certificates
else
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates
fi
cd /tmp
curl -fsSLo aws-emulator-lab.deb https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest/aws-emulator_amd64.deb
if [ "$(id -u)" = 0 ]; then apt-get install -y ./aws-emulator-lab.deb; else sudo apt-get install -y ./aws-emulator-lab.deb; fi
aws-emulator -v
echo 'Inicie em um terminal separado: aws-emulator --telemetry off'
