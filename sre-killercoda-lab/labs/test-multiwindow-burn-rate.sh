#!/usr/bin/env bash
# Aula SRE: avaliar alertas SLO multiwindow/multi-burn (simulação).
# Apenas Python da VM. Dados de exemplo NÃO são métricas coletadas do cluster.
set -euo pipefail
python3 - <<'PY'
from decimal import Decimal

SLO = Decimal("0.999")
ERROR_BUDGET_RATIO = Decimal("1") - SLO

# (total, falhas) em cada janela. Cenarios ficticios para estudo.
CASES = [
    ("saudavel", {"1h": (10000, 0), "5m": (1000, 0), "6h": (60000, 0), "30m": (5000, 0)}),
    ("falha_aguda", {"1h": (10000, 160), "5m": (1000, 20), "6h": (60000, 180), "30m": (5000, 90)}),
    ("falha_sustentada", {"1h": (10000, 70), "5m": (1000, 8), "6h": (60000, 480), "30m": (5000, 40)}),
]

# Regras do Google SRE Workbook para SLO 99,9% / 30 dias:
# PAGE 1h + 5m, ambas >14.4x; PAGE 6h + 30m, ambas >6x.
RULES = [
    ("PAGE_FAST", "1h", "5m", Decimal("14.4")),
    ("PAGE_SUSTAINED", "6h", "30m", Decimal("6")),
]

def rate(total, failed):
    if total <= 0 or not 0 <= failed <= total:
        raise ValueError("Contagem de amostra invalida")
    return Decimal(failed) / Decimal(total)

print("=== SRE MULTIWINDOW / MULTI-BURN-RATE ===")
print("SLO didatico: 99.9% | erro tolerado: 0.1% das requisicoes")
print("Janelas e amostras abaixo sao SIMULADAS, nao sao series temporais reais.")
for name, windows in CASES:
    ratios = {k: rate(*v) for k, v in windows.items()}
    print("\nCENARIO:", name)
    for window in ["1h", "5m", "6h", "30m"]:
        total, failed = windows[window]
        burn = ratios[window] / ERROR_BUDGET_RATIO
        print(f"  {window:>3}: falhas {failed}/{total}, taxa={ratios[window]*100:.3f}%, burn={burn:.2f}x")

    triggered = []
    for severity, long_window, short_window, threshold in RULES:
        long_burn = ratios[long_window] / ERROR_BUDGET_RATIO
        short_burn = ratios[short_window] / ERROR_BUDGET_RATIO
        fires = long_burn > threshold and short_burn > threshold
        print(
            f"  {severity}: burn({long_window})>{threshold}x E "
            f"burn({short_window})>{threshold}x => "
            + ("DISPARA" if fires else "NAO DISPARA")
        )
        if fires:
            triggered.append(severity)
    print("  VEREDITO:", ", ".join(triggered) if triggered else "SEM PAGE")

# Verificacao automatizada do algoritmo. Falha caso mude a regra.
decisions = []
for _, windows in CASES:
    ratios = {k: rate(*v) for k, v in windows.items()}
    decisions.append([
        severity for severity, long_window, short_window, limit in RULES
        if (ratios[long_window] / ERROR_BUDGET_RATIO > limit and
            ratios[short_window] / ERROR_BUDGET_RATIO > limit)
    ])
assert decisions == [[], ["PAGE_FAST"], ["PAGE_SUSTAINED"]], decisions
print("\nSUCESSO: tres cenarios simulados passaram na avaliacao de alertas.")
print("ATENCAO: instalar alertas reais exige coleta continua e historico >= janelas.")
PY
