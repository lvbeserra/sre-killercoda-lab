#!/usr/bin/env bash
# Inventario AZURE SOMENTE LEITURA, sem provisionar, replicar ou executar failover.
# Exige Azure CLI e sessao JA autorizada. Saida pode conter nomes internos.
set -euo pipefail
if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI nao instalada. Este script nao instala nem autentica automaticamente."
  exit 2
fi
if ! az account show --query id --output tsv >/dev/null 2>&1; then
  echo "Sem sessao Azure CLI autenticada. Use apenas conta sandbox aprovada."
  exit 2
fi
echo "=== ASSINATURA ATIVA (IDs OMITIDOS) ==="
az account show --query '{name:name,tenant:tenantDisplayName}' -o table
echo "=== RECOVERY SERVICES VAULTS ==="
az resource list --resource-type Microsoft.RecoveryServices/vaults --query \
  '[].{Vault:name,ResourceGroup:resourceGroup,Region:location}' -o table
echo "=== WORKSPACES DE LOG ANALYTICS ==="
az resource list --resource-type Microsoft.OperationalInsights/workspaces --query \
  '[].{Workspace:name,ResourceGroup:resourceGroup,Region:location}' -o table
echo "=== ATENCAO ==="
echo "Esta consulta lista recursos, nao valida ASR, replicacao, pontos de recuperacao ou RPO."
echo "Nao execute failover sem autorizacao e nao publique nomes de recursos internos."
