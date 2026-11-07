#!/usr/bin/env bash
# Checkpoint seguro do laboratório; executar manualmente ou via start-checkpoints.sh.
set -euo pipefail
cd "$(dirname "$0")"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERRO: execute dentro do clone Git do laboratório." >&2
  exit 1
fi
if ! kubectl get namespace sre-release-lab >/dev/null 2>&1; then
  echo "ERRO: namespace sre-release-lab indisponível; não registrarei um estado inexistente." >&2
  exit 1
fi

STAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
{
  printf '\n## Checkpoint da sessão — %s\n\n' "$STAMP"
  printf 'Contexto: \`%s\`.\n\n' "$(kubectl config current-context)"
  printf '\`\`\`text\n'
  kubectl get nodes
  kubectl -n sre-release-lab get deployments,pods,services -o wide
  kubectl -n sre-release-lab get endpointslices -o wide
  printf '\`\`\`\n\n'
  echo "Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint."
} >> docs/PROGRESSO.md

# Lista permitida de arquivos; NUNCA adiciona tokens, kubeconfig, Secrets ou logs inteiros.
git add -- docs/*.md labs/*.yaml labs/*.sh labs/*.html apps/payment-bridge/bridge.py apps/payment-bridge/requirements.txt lab-completo.yaml README.md restore.sh validate.sh checkpoint.sh start-checkpoints.sh setup.sh ../iniciar.sh ../README.md

if git diff --cached --quiet; then
  echo "Nenhuma alteração para salvar."
  exit 0
fi

if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
  echo "ERRO: configure git user.name e user.email antes de commitar." >&2
  exit 1
fi

git commit -m "checkpoint SRE: $STAMP"
if GIT_TERMINAL_PROMPT=0 git push origin HEAD:main; then
  echo "SUCESSO: checkpoint publicado no GitHub."
else
  echo "ATENÇÃO: commit salvo APENAS NESTA VM. Push falhou!" >&2
  echo "Faça push com autenticação segura ou peça checkpoint via ChatGPT antes que o KillerCoda expire." >&2
  exit 1
fi
