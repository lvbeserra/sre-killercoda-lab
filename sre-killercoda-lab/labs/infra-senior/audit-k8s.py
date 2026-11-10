#!/usr/bin/env python3
"""Auditoria SOMENTE LEITURA do Kubernetes: capacidade, rede, storage e governança.

Exercício de Infraestrutura Sênior / FinOps em cluster descartável.
Usa Python padrão e kubectl já autenticado; não altera recursos e não lê Secrets.
"""
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict

def read(kind):
    cmd = ["kubectl", "get", kind, "-A", "-o", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode:
        print("ERRO em", " ".join(cmd), result.stderr.strip(), file=sys.stderr)
        sys.exit(2)
    return json.loads(result.stdout)["items"]

def cpu_millicores(text):
    v = str(text or "0")
    if v.endswith("m"):
        return float(v[:-1])
    if v.endswith("u"):
        return float(v[:-1]) / 1000
    if v.endswith("n"):
        return float(v[:-1]) / 1000000
    return float(v) * 1000

def memory_mib(text):
    v = str(text or "0")
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)(Ki|Mi|Gi|Ti|K|M|G|T)?", v)
    if not match:
        return 0.0
    value = float(match.group(1))
    suffix = match.group(2)
    factors = {"Ki": 1 / 1024, "Mi": 1, "Gi": 1024, "Ti": 1048576,
               "K": 1000 / (1024 * 1024), "M": 1000000 / (1024 * 1024),
               "G": 1000000000 / (1024 * 1024), "T": 1000000000000 / (1024 * 1024)}
    return value * factors.get(suffix, 1 / (1024 * 1024))

def main():
    nodes = read("nodes")
    pods = read("pods")
    deployments = read("deployments")
    pvcs = read("pvc")
    policies = read("networkpolicies")
    services = read("services")

    print("=== AUDITORIA DE INFRAESTRUTURA KUBERNETES (READ-ONLY) ===")
    print(f"Nodes: {len(nodes)} | Pods: {len(pods)} | Deployments: {len(deployments)}")
    print(f"Services: {len(services)} | PVCs: {len(pvcs)} | NetworkPolicies: {len(policies)}")
    print("Estes contadores sao de recursos, nao auditoria definitiva de seguranca.")

    usage = defaultdict(lambda: {"cpu_req": 0.0, "mem_req": 0.0,
                                 "cpu_lim": 0.0, "mem_lim": 0.0, "pods": 0})
    missing = Counter()
    phases = Counter()

    for pod in pods:
        status = pod.get("status", {}).get("phase", "Unknown")
        phases[status] += 1
        if status in ("Succeeded", "Failed"):
            continue
        node_name = pod.get("spec", {}).get("nodeName")
        if not node_name:
            continue
        usage[node_name]["pods"] += 1
        for container in pod.get("spec", {}).get("containers", []):
            resources = container.get("resources", {})
            requests = resources.get("requests", {})
            limits = resources.get("limits", {})
            usage[node_name]["cpu_req"] += cpu_millicores(requests.get("cpu"))
            usage[node_name]["mem_req"] += memory_mib(requests.get("memory"))
            usage[node_name]["cpu_lim"] += cpu_millicores(limits.get("cpu"))
            usage[node_name]["mem_lim"] += memory_mib(limits.get("memory"))
            if not requests.get("cpu") or not requests.get("memory"):
                missing["requests_incompletos"] += 1
            if not limits.get("memory"):
                missing["sem_limite_memoria"] += 1

    print("\n=== CAPACIDADE DECLARADA POR NODE ===")
    for node in nodes:
        name = node["metadata"]["name"]
        alloc = node.get("status", {}).get("allocatable", {})
        capacity_cpu = cpu_millicores(alloc.get("cpu"))
        capacity_mem = memory_mib(alloc.get("memory"))
        used = usage[name]
        cpu_pct = used["cpu_req"] / capacity_cpu * 100 if capacity_cpu else 0
        mem_pct = used["mem_req"] / capacity_mem * 100 if capacity_mem else 0
        print(f"{name}: Pods={used['pods']}, CPU requests={used['cpu_req']:.0f}m/"
              f"{capacity_cpu:.0f}m ({cpu_pct:.1f}%), "
              f"Mem requests={used['mem_req']:.0f}Mi/{capacity_mem:.0f}Mi ({mem_pct:.1f}%), "
              f"Mem limits totais={used['mem_lim']:.0f}Mi")
    print("Importante: requests/limits NAO sao consumo medido. "
          "O calculo aproximado nao inclui initContainers, overhead e detalhes do scheduler.")

    print("\n=== SAUDE E CONTROLES ===")
    print("Fases dos Pods:", dict(phases))
    unhealthy = []
    for deployment in deployments:
        spec = deployment.get("spec", {})
        status = deployment.get("status", {})
        desired = int(spec.get("replicas", 1))
        ready = int(status.get("readyReplicas") or 0)
        if ready < desired:
            unhealthy.append(f"{deployment['metadata']['namespace']}/{deployment['metadata']['name']} {ready}/{desired}")
    print("Deployments sem todas as replicas Ready:", unhealthy or "nenhum")
    print("Containers sem requests completos (CPU+memoria):", missing["requests_incompletos"])
    print("Containers sem memory limit:", missing["sem_limite_memoria"])
    print("PVCs por estado:", dict(Counter(x.get("status", {}).get("phase", "Unknown") for x in pvcs)))
    print("NetworkPolicies por namespace:",
          dict(Counter(x["metadata"]["namespace"] for x in policies)))

    print("\n=== INTERPRETACAO PARA ENTREVISTA ===")
    print("1. Avaliei saude dos Deployments e capacidade declarada dos nodes.")
    print("2. Identifiquei oportunidades de revisar requests/limits, storage e isolamento.")
    print("3. Para FinOps real, eu correlacionaria utilizacao medida, custos e requisitos de negocio.")
    print("4. Para governanca real, validaria RBAC, network policies e Secrets com permissoes adequadas.")
    print("5. Nao executei alteracoes nem estimei custo financeiro a partir de requests.")

if __name__ == "__main__":
    try:
        main()
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(f"Falha ao executar kubectl: {exc}", file=sys.stderr)
        sys.exit(2)
