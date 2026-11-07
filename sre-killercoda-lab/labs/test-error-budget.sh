#!/usr/bin/env bash
# Aula SRE: calcular error budget didático para SLO de requisições HTTP.
# Não altera cluster; não acessa a rede; usa apenas Python 3.
set -euo pipefail
TOTAL="$1"
FALHAS="$2"
python3 - "$TOTAL" "$FALHAS" <<'PY'
import sys
from decimal import Decimal, ROUND_HALF_UP

try:
    total = int(sys.argv[1])
    falhas = int(sys.argv[2])
except (ValueError, IndexError) as exc:
    raise SystemExit("Uso: bash labs/test-error-budget.sh TOTAL_REQUISICOES FALHAS") from exc

if total <= 0 or not 0 <= falhas <= total:
    raise SystemExit("ERRO: TOTAL > 0; 0 <= FALHAS <= TOTAL.")

alvo = Decimal("0.999")
erro_permitido = Decimal(1) - alvo
erro_observado = Decimal(falhas) / Decimal(total)
disponibilidade = (Decimal(1) - erro_observado) * 100
orcamento_amostra = Decimal(total) * erro_permitido
burn_rate = erro_observado / erro_permitido

print("=== SLO DIDÁTICO POR REQUISIÇÕES ===")
print("Objetivo hipotético: 99,9% de respostas bem-sucedidas numa janela de 30 dias")
print(f"Requisições: {total}; falhas: {falhas}")
print(f"SLI observado nesta AMOSTRA: {disponibilidade:.3f}%")
print(f"Budget proporcional à amostra: {orcamento_amostra:.3f} falhas")
print(f"Taxa de consumo do budget (burn rate): {burn_rate:.2f}x")
if erro_observado > erro_permitido:
    print("ALERTA DIDÁTICO: taxa de falhas nesta amostra supera a meta.")
else:
    print("AMOSTRA: taxa de falhas não supera a meta.")
print()
print("=== SLO ALTERNATIVO POR TEMPO (não é a mesma medição) ===")
janela_segundos = 30 * 24 * 60 * 60
segundos_indisponiveis = int((Decimal(janela_segundos) * erro_permitido).to_integral_value(rounding=ROUND_HALF_UP))
minutos, segundos = divmod(segundos_indisponiveis, 60)
print(f"Para uma meta baseada em TEMPO de 99,9% em 30 dias: {minutos}m{segundos:02}s de indisponibilidade tolerada.")
print()
print("LIMITAÇÃO: 20/20 ou 40/40 sucessos NÃO comprovam um SLO mensal.")
print("Para alertas reais: amostragem contínua, persistência externa e janelas temporais.")
PY
