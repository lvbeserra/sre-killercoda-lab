#!/usr/bin/env bash
# Use source .../env.sh no terminal em que vai rodar AWS CLI.
if [ ! -s "$HOME/.aws/emulator/9297/emulator_credentials" ]; then
  echo 'Emulador nao iniciado ou arquivo de credenciais temporarias ausente.' >&2
  return 1 2>/dev/null || exit 1
fi
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
export AWS_ENDPOINT_URL=https://127.0.0.1:9297
export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/emulator/9297/emulator_credentials"
export AWS_CONFIG_FILE="$HOME/.aws/emulator/9297/config"
export AWS_CA_BUNDLE="$HOME/.aws/emulator/9297/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_DISABLE_HOST_PREFIX_INJECTION=true
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=''
echo 'CLI configurado para o AWS Emulator em https://127.0.0.1:9297'
