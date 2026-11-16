# Aula 05 — EC2 / VPC / Subnet / Security Group (AWS Emulator)

**Em 16/11/2026, validado manualmente pelo Luiz no KillerCoda (AWS Emulator 1.0.471):** `aws ec2 describe-instances` devolveu lista vazia; `aws ec2 describe-vpcs` mostrou VPC default `172.31.0.0/16` (`vpc-00000000000000001`). O comando `aws ec2 run-instances --image-id ami-0c02fb55956c7d316 --instance-type t3.micro --count 1 --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=SRE-LAB-EC2-01}]'` retornou `i-00000000000000001`; `describe-instances` confirmou estado `running`, tipo `t3.micro` e IP privado ficticio `172.31.0.4`.

**Limitacao essencial:** o estado EC2 `running`, IP publico e DNS retornados sao **somente dados simulados**. O AWS Emulator nao cria uma maquina virtual/guest Linux real: nao e possivel usar SSH nela. Nao confundir com provisionamento EC2 na AWS real.

## Restaure/crie a Aula 05

Depois de executar `bootstrap.sh`, rode:

```bash
cd ~/sre-killercoda-lab
git pull --ff-only origin main
bash sre-killercoda-lab/labs/aws-emulator/aula05/run.sh
```

O script:
1. valida endpoint local `https://127.0.0.1:9297` e Account `000000000000`;
2. identifica VPC e subnet padrao existentes;
3. cria Security Group `SRE-LAB-SG` **sem regras de entrada** se ainda nao existir;
4. cria uma EC2 simulada `SRE-LAB-EC2-01` se nao encontrar instancia homonima;
5. exibe resumo por AWS CLI.

**Teste do script ainda pendente:** a chamada direta a `RunInstances` foi validada, mas a cadeia de criacao SG+subnet+instancia ainda precisa ser executada pelo usuario no KillerCoda. Se houver `NotImplemented` em alguma operacao, preserve a saida para adequar ao suporte da versao.

## Consultas

```bash
source ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/env.sh
aws ec2 describe-instances --output table
aws ec2 describe-vpcs --output table
aws ec2 describe-security-groups --output table
aws ec2 describe-subnets --output table
```

Nao abra SSH (porta 22) neste laboratorio; nenhum trafego sera entregue a uma VM real. Nao use IPs/DNSs emulados como destinos de rede.
O codigo e a documentacao ficam no GitHub; o estado da EC2 emulada desaparece quando a sessao expira.
