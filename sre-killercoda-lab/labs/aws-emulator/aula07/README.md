# Aula 07 — EKS, IAM e Managed Node Groups (AWS Emulator)

## Objetivo
Reproduzir chamadas de controle do EKS, IAM e VPC/SUBNET sem usar conta AWS real e sem provisionar VMs reais.

Testes executados no Killercoda em 17/11/2026:
- `aws iam create-role` para cluster e nodes retornou sucesso.
- `aws eks create-cluster` criou `SRE-LAB-EKS-01`, versao 1.33; `describe-cluster` retornou `ACTIVE`.
- `aws eks create-nodegroup` criou `SRE-LAB-NODES` com minSize=1, maxSize=2, desiredSize=1; `describe-nodegroup` retornou `ACTIVE`.
- API Kubernetes emulada `/version`, `/api/v1/namespaces` e `/api/v1/nodes` responderam HTTP 200. O node emulado aparece `Ready=True`.
- `POST /api/v1/namespaces/default/pods` aceitou um Nginx com HTTP 201 e o agendou, mas o Pod terminou em `Failed` / `StartError` / exit code 128: **"This emulator does not run containers, so the pod's containers were never started"**.

## Executar ou restaurar

```bash
cd ~/sre-killercoda-lab
source sre-killercoda-lab/labs/aws-emulator/env.sh
bash sre-killercoda-lab/labs/aws-emulator/aula07/run.sh
```

O script exige conta ficticia `000000000000` e endpoint HTTPS local `127.0.0.1:9297`; cria IAM Roles somente se nao existirem; reutiliza cluster e Node Group existentes sem modificá-los. Requer VPC default com duas subnets em AZs diferentes, que o AWS Emulator fornece. O script nao cria Pods de teste automaticamente, para evitar falhas artificiais no restore.

## Validacao manual

```bash
aws eks list-clusters
aws eks list-nodegroups --cluster-name SRE-LAB-EKS-01
aws eks describe-nodegroup --cluster-name SRE-LAB-EKS-01 --nodegroup-name SRE-LAB-NODES --query 'nodegroup.[status,scalingConfig]' --output json
aws eks describe-cluster --name SRE-LAB-EKS-01 --query 'cluster.[status,endpoint]' --output json
```

A URL do endpoint Kubernetes emulado usa uma porta dinamica e **muda entre sessoes**. Para verificar a API, pegue-a de `describe-cluster`. `Ready=True` de um Node representa estado simulado e **nao confirma capacidade de executar containers**. Para estudar execucao real de Pods, use ambiente Kubernetes com nodes reais.

Documentacao: https://docs.aws.amazon.com/emulator/latest/userguide/
