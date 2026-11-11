#!/usr/bin/env python3
"""Simulador educacional de BCDR/ASR: SEM AZURE, VMs ou falhas reais.

Representa checkpoints de replicação e ordenação de Recovery Plan com um
relógio virtual. O RPO exibido é a idade do checkpoint replicado no instante
da falha; o RTO é o tempo de detecção + restauração no cenário simulado.
Não usa rede, kubectl, storage remoto ou credenciais.
"""
from __future__ import annotations

import argparse
import copy
import json
from dataclasses import dataclass, asdict

EVENT_TIMES = (10, 40, 70, 100, 130)  # segundos, fictícios
FAILURE_TIME = 150
REPLICA_CHECKPOINT_TIME = 90
STEPS = (
    ("validar_identidade_e_acessos", 5),
    ("validar_rede_vpn_dns", 10),
    ("recuperar_storage", 8),
    ("iniciar_banco_de_dados", 12),
    ("iniciar_aplicacao", 10),
    ("validar_monitoramento", 5),
)


@dataclass(frozen=True)
class Event:
    id: str
    timestamp_seconds: int


def primary_events() -> list[Event]:
    return [Event("TX-SIM-%03d" % i, t) for i, t in enumerate(EVENT_TIMES, 1)]


def replica_at(events: list[Event], checkpoint_seconds: int) -> list[Event]:
    return [e for e in events if e.timestamp_seconds <= checkpoint_seconds]


def run_plan() -> tuple[list[dict], int]:
    timeline = []
    elapsed = 0
    for name, duration in STEPS:
        elapsed += duration
        timeline.append({"step": name, "duration_seconds": duration, "finished_at_plus_seconds": elapsed})
    return timeline, elapsed


def evaluate(name: str, rpo_target: int, rto_target: int) -> dict:
    primary = primary_events()
    replicated = replica_at(primary, REPLICA_CHECKPOINT_TIME)
    steps, plan_seconds = run_plan()
    result = {
        "scenario": name,
        "kind": "SIMULACAO_EDUCACIONAL_NAO_AZURE",
        "source_events": len(primary),
        "recovery_plan_steps": steps,
        "target_rpo_seconds": rpo_target,
        "target_rto_seconds": rto_target,
    }

    if name == "test-failover":
        isolated_copy = copy.deepcopy(replicated)
        assert isolated_copy == replicated and primary == primary_events()
        result.update({
            "primary_stays_running": True,
            "isolated_test_network": True,  # conceito simulado
            "test_copy_events": len(isolated_copy),
            "production_route_changed": False,
            "cleanup": "copia ficticia descartada ao final; nao existem VMs Azure",
            "result": "PASSOU_SIMULACAO_ISOLAMENTO",
        })
        return result

    if name == "planned":
        # Procedimento planejado: parar escrita e sincronizar toda a fila antes
        # de ativar a cópia. Sem perda no modelo, não é garantia em produção.
        recovered = copy.deepcopy(primary)
        recovery_point_seconds = FAILURE_TIME
        detection_delay = 0
    elif name == "unplanned":
        recovered = copy.deepcopy(replicated)
        recovery_point_seconds = REPLICA_CHECKPOINT_TIME
        detection_delay = 50  # premissa do exercício, tempo até acionar DR
    else:
        raise ValueError("Cenário desconhecido")

    recovery_point_age = FAILURE_TIME - recovery_point_seconds
    rto = detection_delay + plan_seconds
    lost_ids = [e.id for e in primary if e.id not in {x.id for x in recovered}]
    result.update({
        "source_failure_virtual_second": FAILURE_TIME,
        "replication_checkpoint_virtual_second": recovery_point_seconds,
        "recovery_point_age_seconds": recovery_point_age,
        "rpo_meets_target": recovery_point_age <= rpo_target,
        "rto_seconds": rto,
        "rto_meets_target": rto <= rto_target,
        "not_recovered_event_ids": lost_ids,
        "recovered_events": len(recovered),
        "operator_detection_seconds": detection_delay,
        "result": "RECUPERADO_NO_MODELO",
    })

    # Failback planejado: sincroniza a cópia que está servindo no DR de volta
    # à origem reconstruída. Não recupera eventos perdidos antes do desastre.
    dr_new_event = Event("TX-SIM-DR-001", FAILURE_TIME + rto + 10)
    recovered.append(dr_new_event)
    rebuilt_primary = copy.deepcopy(recovered)
    assert rebuilt_primary == recovered
    result["failback"] = {
        "type": "sincronizacao_reversa_simulada",
        "dr_new_event_synchronized": dr_new_event.id in {e.id for e in rebuilt_primary},
        "unrecovered_source_events_remain_lost": lost_ids,
        "requires_data_reconciliation": bool(lost_ids),
    }
    return result


def selftest():
    planned = evaluate("planned", 30, 120)
    unexpected = evaluate("unplanned", 30, 120)
    drill = evaluate("test-failover", 30, 120)
    assert planned["recovery_point_age_seconds"] == 0
    assert planned["not_recovered_event_ids"] == []
    assert planned["rpo_meets_target"] and planned["rto_meets_target"]
    assert unexpected["recovery_point_age_seconds"] == 60
    assert unexpected["not_recovered_event_ids"] == ["TX-SIM-004", "TX-SIM-005"]
    assert unexpected["rpo_meets_target"] is False
    assert unexpected["rto_meets_target"] is True
    assert unexpected["failback"]["requires_data_reconciliation"] is True
    assert drill["primary_stays_running"] and not drill["production_route_changed"]
    print("SUCESSO: 3 cenários e validações do modelo passaram.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", choices=("all", "test-failover", "planned", "unplanned"), default="all")
    parser.add_argument("--rpo-target", type=int, default=30, help="segundos, alvo didático")
    parser.add_argument("--rto-target", type=int, default=120, help="segundos, alvo didático")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.rpo_target < 0 or args.rto_target < 0:
        parser.error("RPO/RTO devem ser >= 0")
    selftest()
    if args.self_test:
        return
    scenarios = ["test-failover", "planned", "unplanned"] if args.scenario == "all" else [args.scenario]
    for scenario in scenarios:
        print(json.dumps(evaluate(scenario, args.rpo_target, args.rto_target), ensure_ascii=False, indent=2))
    print("AVISO: simulação com relógio virtual. Não cria recursos Azure, não replica VM, não garante RPO/RTO operacional.")


if __name__ == "__main__":
    main()
