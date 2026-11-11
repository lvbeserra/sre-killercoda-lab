#!/usr/bin/env python3
"""Aula Infra Sênior: detalhar lacunas de requests/limits e consumo (somente leitura).
Nenhuma alteração no cluster. Não consulta valores de Secrets nem credenciais.
"""
import json
import subprocess
import sys
from collections import defaultdict

def kubectl(*args):
    cmd = ["kubectl", *args]
    p = subprocess.run(cmd, text=True, capture_output=True, timeout=35)
    if p.returncode:
        raise RuntimeError(" ".join(cmd) + " -> " + p.stderr.strip())
    return p.stdout

def main():
    pods = json.loads(kubectl("get", "pods", "-A", "-o", "json"))["items"]
    issues = []
    totals = defaultdict(lambda: {"containers": 0, "missing_req": 0, "missing_mem_limit": 0})
    all_containers = 0
    for pod in pods:
        if pod.get("status", {}).get("phase") in ("Succeeded", "Failed"):
            continue
        ns = pod["metadata"]["namespace"]
        name = pod["metadata"]["name"]
        node = pod.get("spec", {}).get("nodeName", "<pending>")
        for container in pod.get("spec", {}).get("containers", []):
            all_containers += 1
            totals[ns]["containers"] += 1
            res = container.get("resources") or {}
            req = res.get("requests") or {}
            lim = res.get("limits") or {}
            defects = []
            if not req.get("cpu") or not req.get("memory"):
                defects.append("REQUESTS_INCOMPLETOS")
                totals[ns]["missing_req"] += 1
            if not lim.get("memory"):
                defects.append("SEM_MEMORY_LIMIT")
                totals[ns]["missing_mem_limit"] += 1
            if defects:
                issues.append((ns, name, container["name"], node,
                               req.get("cpu", "-"), req.get("memory", "-"),
                               lim.get("memory", "-"), ",".join(defects)))

    print("=== AUDITORIA DETALHADA — REQUESTS E LIMITS (READ-ONLY) ===")
    print(f"Containers ativos examinados: {all_containers}")
    print("NS | POD | CONTAINER | NODE | CPU_REQ | MEM_REQ | MEM_LIMIT | ALERTAS")
    for row in issues:
        print(" | ".join(row))
    if not issues:
        print("Nenhum container sem requests de CPU/memoria ou sem limite de memoria encontrado.")

    print("\n=== RESUMO POR NAMESPACE ===")
    for ns in sorted(totals):
        x = totals[ns]
        print(f"{ns}: containers={x['containers']}, requests_incompletos={x['missing_req']}, sem_mem_limit={x['missing_mem_limit']}")

    print("\n=== CONSUMO EFETIVO (METRICS API, SE DISPONIVEL) ===")
    for resource in ("nodes", "pods"):
        arguments = ("top", resource) if resource == "nodes" else ("top", "pods", "-A", "--sort-by=memory")
        try:
            result = kubectl(*arguments)
            lines = result.strip().splitlines()
            print(f"kubectl {' '.join(arguments)}:")
            print("\n".join(lines[:20]) or "(sem amostras)")
            if len(lines) > 20:
                print(f"... ({len(lines) - 20} linhas omitidas)")
        except RuntimeError as exc:
            print(f"Metrics API indisponivel para {resource}: {exc}")
    print("\n=== INTERPRETACAO ===")
    print("Requests/limits sao configuracoes; kubectl top mede utilizacao pontual quando Metrics Server existe.")
    print("Namespace kube-system pode ter necessidades diferentes; nao alterar Deployments de plataforma sem avaliacao.")
    print("Falta de NetworkPolicy padrão nao confirma ausencia de controles Cilium/externos.")
    print("Nao aplicar ajustes sem medir consumo, planejar riscos e validar rollback.")

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired, FileNotFoundError) as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        sys.exit(2)
