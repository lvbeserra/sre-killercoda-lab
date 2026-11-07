#!/usr/bin/env bash
# Iniciar laboratório SRE em uma sessão NOVA do KillerCoda.
# Instala GitHub CLI se faltar, autentica por dispositivo, restaura e agenda checkpoints.
set -euo pipefail
cd "$(dirname "$0")"

echo "=== SRE KILLERCODA: PRE-FLIGHT ==="
for bin in git kubectl bash; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERRO: comando obrigatório ausente: $bin" >&2
    exit 1
  fi
done
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERRO: clone este repositório com git antes de executar." >&2
  exit 1
fi
kubectl config current-context
kubectl get nodes

if ! command -v gh >/dev/null 2>&1; then
  echo "=== Instalando GitHub CLI (gh) ==="
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERRO: apt-get indisponível. Instale gh manualmente conforme sua distribuição." >&2
    exit 1
  fi
  if [[ $(id -u) -eq 0 ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y gh
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y gh
  else
    echo "ERRO: instalacao requer root ou sudo." >&2
    exit 1
  fi
fi
echo "GitHub CLI: $(gh --version | head -1)"

# Não armazenar tokens dentro do Git ou do repositório.
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  if [[ ! -t 0 ]]; then
    echo "ERRO: execute interativamente para autorizar o acesso ao GitHub." >&2
    exit 1
  fi
  echo
  echo "=== AUTENTICACAO GITHUB ==="
  echo "O gh mostrará um código temporário. Abra https://github.com/login/device"
  echo "no navegador do seu computador e autorize SUA conta."
  echo "Nunca salve tokens ou códigos no repositório."
  gh auth login --hostname github.com --git-protocol https --web
fi
LOGIN=$(gh api user --jq '.login')
if [[ "$LOGIN" != "lvbeserra" ]]; then
  echo "ERRO: autenticado como '$LOGIN', esperado 'lvbeserra'." >&2
  echo "Confira sua conta antes de permitir push no repositório." >&2
  exit 1
fi
gh auth setup-git

# Apenas neste clone, não altera Git global do ambiente.
git config --local user.name "Luiz Beserra"
git config --local user.email "126087437+lvbeserra@users.noreply.github.com"

echo "=== RESTAURANDO LABORATORIO ==="
bash restore.sh

echo "=== VALIDANDO LABORATORIO PRINCIPAL ==="
bash validate.sh

echo "=== INICIANDO CHECKPOINTS ANTES DO MIDDLEWARE ==="
bash start-checkpoints.sh

echo "=== INICIANDO APACHE, KAFKA E RABBITMQ ==="
# Desative num cenário com pouca memória usando SRE_ENABLE_MIDDLEWARE=0.
if [[ "${SRE_ENABLE_MIDDLEWARE:-1}" == "1" ]]; then
  if bash labs/restore-middleware.sh; then
    echo "=== VALIDANDO MIDDLEWARE ==="
    bash labs/validate-middleware.sh || echo "AVISO: middleware ainda nao validou; confira kubectl -n sre-middleware-lab get pods e logs."
  else
    echo "AVISO: implantacao middleware com falha; laboratorio base e checkpoints continuam ativos."
  fi
else
  echo "Middleware desativado por SRE_ENABLE_MIDDLEWARE=0."
fi
echo
echo "Bootstrap finalizado: confira o status de todos os Pods e o sucesso do git push no log."
echo "Confira envio: sleep 3; tail -30 /tmp/sre-checkpoints.log"
echo "IMPORTANTE: a VM e a autenticacao do gh não persistem entre sessões KillerCoda."
