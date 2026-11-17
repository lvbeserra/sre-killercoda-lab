#!/usr/bin/env bash
# Aula 07: IAM / EKS / Managed Node Group simulados. Nao executa containers reais.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$lab_dir/../env.sh"
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION=us-east-1
account="$(aws sts get-caller-identity --query Account --output text)"
if [ "${AWS_ENDPOINT_URL:-}" != https://127.0.0.1:9297 ] || [ "$account" != 000000000000 ]; then
  echo 'ABORTADO: requer AWS Emulator local e conta ficticia 000000000000.' >&2
  exit 1
fi
cluster=SRE-LAB-EKS-01
nodegroup=SRE-LAB-NODES
cluster_role=SRE-LAB-EKS-ROLE
node_role=SRE-LAB-EKS-NODE-ROLE
cluster_arn="arn:aws:iam::$account:role/$cluster_role"
node_arn="arn:aws:iam::$account:role/$node_role"
ensure_role() {
  local name="$1" principal="$2"
  if aws iam get-role --role-name "$name" >/dev/null 2>&1; then
    echo "Role IAM existente: $name"
  else
    local policy
    policy="$(printf '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"%s"},"Action":"sts:AssumeRole"}]}' "$principal")"
    aws iam create-role --role-name "$name" --assume-role-policy-document "$policy" --query 'Role.Arn' --output text
    echo "Role IAM criada: $name"
  fi
}
ensure_role "$cluster_role" eks.amazonaws.com
ensure_role "$node_role" ec2.amazonaws.com
vpc="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
if [ -z "$vpc" ] || [ "$vpc" = None ]; then
  echo 'VPC padrao inexistente no emulador.' >&2
  exit 1
fi
mapfile -t subnets < <(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query 'Subnets[].[SubnetId,AvailabilityZone]' --output text | awk '!seen[$2]++ {print $1}' | head -n 2)
if [ "${#subnets[@]}" -lt 2 ]; then
  echo 'Aula 07 requer ao menos duas subnets em zonas de disponibilidade distintas.' >&2
  exit 1
fi
if aws eks describe-cluster --name "$cluster" >/dev/null 2>&1; then
  echo "Cluster EKS emulado existente: $cluster"
else
  aws eks create-cluster --name "$cluster" --kubernetes-version 1.33 --role-arn "$cluster_arn" --resources-vpc-config "subnetIds=${subnets[0]},${subnets[1]}" --query 'cluster.[name,status]' --output json
fi
aws eks wait cluster-active --name "$cluster"
if aws eks describe-nodegroup --cluster-name "$cluster" --nodegroup-name "$nodegroup" >/dev/null 2>&1; then
  echo "Node Group existente: $nodegroup (configuracao preservada)"
else
  aws eks create-nodegroup --cluster-name "$cluster" --nodegroup-name "$nodegroup" --node-role "$node_arn" --subnets "${subnets[@]}" --instance-types t3.micro --scaling-config minSize=1,maxSize=2,desiredSize=1 --query 'nodegroup.[nodegroupName,status]' --output json
fi
aws eks wait nodegroup-active --cluster-name "$cluster" --nodegroup-name "$nodegroup"
echo 'EKS:'
aws eks describe-cluster --name "$cluster" --query 'cluster.[name,status,version,endpoint]' --output json
echo 'Node Group:'
aws eks describe-nodegroup --cluster-name "$cluster" --nodegroup-name "$nodegroup" --query 'nodegroup.[nodegroupName,status,scalingConfig]' --output json
echo 'AVISO: EKS e nodes simulados; nao ha execucao real de containers.'
