#!/usr/bin/env bash
# Aula 05: EC2 simulada com SG fechado. Apenas AWS Emulator local.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$lab_dir/../env.sh"
account="$(aws sts get-caller-identity --query Account --output text)"
if [ "$account" != 000000000000 ] || [ "${AWS_ENDPOINT_URL:-}" != https://127.0.0.1:9297 ]; then
  echo 'ABORTADO: somente conta ficticia no endpoint local.' >&2
  exit 1
fi
vpc_id="$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
if [ -z "$vpc_id" ] || [ "$vpc_id" = None ]; then
  echo 'VPC padrao nao encontrada no emulador.' >&2
  exit 1
fi
subnet_id="$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0].SubnetId' --output text)"
if [ -z "$subnet_id" ] || [ "$subnet_id" = None ]; then
  echo 'Subnet padrao nao encontrada no emulador.' >&2
  exit 1
fi
sg_id="$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" Name=group-name,Values=SRE-LAB-SG --query 'SecurityGroups[0].GroupId' --output text)"
if [ -z "$sg_id" ] || [ "$sg_id" = None ]; then
  sg_id="$(aws ec2 create-security-group --group-name SRE-LAB-SG --description 'SG laboratorio EC2 emulado sem ingress' --vpc-id "$vpc_id" --query GroupId --output text)"
  echo "Security Group criado: $sg_id (sem regras de entrada)"
else
  echo "Security Group existente: $sg_id"
fi
instance_id="$(aws ec2 describe-instances --filters Name=tag:Name,Values=SRE-LAB-EC2-01 --query 'Reservations[].Instances[].InstanceId' --output text)"
if [ -z "$instance_id" ] || [ "$instance_id" = None ]; then
  instance_id="$(aws ec2 run-instances --image-id ami-0c02fb55956c7d316 --instance-type t3.micro --count 1 --subnet-id "$subnet_id" --security-group-ids "$sg_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=SRE-LAB-EC2-01}]' --query 'Instances[0].InstanceId' --output text)"
  echo "EC2 SIMULADA criada: $instance_id"
else
  echo "EC2 SIMULADA preexistente: $instance_id (nao alterada)"
fi
aws ec2 describe-instances --filters Name=tag:Name,Values=SRE-LAB-EC2-01 --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,VpcId,SubnetId,PrivateIpAddress]' --output table
echo 'IMPORTANTE: running no AWS Emulator nao significa VM Linux real; SSH nao funciona.'
