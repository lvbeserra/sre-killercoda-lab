# SRE KillerCoda — laboratório recuperável

Laboratório prático e descartável de Linux LPIC-2, Docker, Kubernetes, Cilium/eBPF, observabilidade, Blue-Green, graceful shutdown, rolling update, SRE, segurança e FinOps.

## Por que existe

KillerCoda gratuito encerra a sessão após cerca de **1 hora** e apaga o ambiente. O GitHub preserva **a definição do laboratório** e **o histórico do curso**, não o estado da VM.

## Restaurar em um novo KillerCoda

Abra o cenário **Kubernetes single node** e confira o contexto e nó. Faça clone de seu repositório GitHub e aplique:

```bash
kubectl config current-context
kubectl get nodes
# Depois de publicar os arquivos no GitHub:
git clone https://github.com/SEU_USUARIO/sre-killercoda-lab.git
cd sre-killercoda-lab
bash restore.sh
bash validate.sh
```

Se o repositório for privado, faça clone somente com autenticação segura. Não cole tokens em um terminal do KillerCoda: o ambiente é temporário e suas sessões podem registrar comandos. Para um repositório público que contém **somente estes manifests de laboratório**, o clone HTTPS é suficiente.

**Sem GitHub ainda?** Extraia este pacote e leve os arquivos para seu repositório; se `restore.sh` já estiver presente na sessão, rode `bash restore.sh`.

## Conteúdo

- `lab-completo.yaml`: namespaces; Blue (2 pods) e Green (1 pod); Service principal Blue e Service Green; ConfigMap Python de /ready e /slow; drain-demo (2 pods) com preStop 5s, SIGTERM, grace period 30s, maxUnavailable 0 e maxSurge 1; Service drain-demo.
- `restore.sh`: aplica tudo, aguarda rollout e verifica saúde.
- `validate.sh`: checa Service/DNS/HTTP, status de deployments e Cilium.
- `labs/cpu-benchmark-opcional.yaml`: dois Jobs de CPU. Rode **um por vez** para não contaminar a comparação.
- `docs/PROGRESSO.md`: checkpoint detalhado das aulas e próximo teste.
- `docs/GITHUB.md`: como publicar no GitHub com navegador ou Git CLI.
- `.gitignore`: impede versionamento acidental de credenciais e logs locais.

## Operação após cada aula

1. Atualize `docs/PROGRESSO.md` com *o que foi validado* e *o próximo comando*.
2. Ajuste o `lab-completo.yaml` para refletir **o estado desejado da próxima sessão**. Se fizer um patch de Kubernetes apenas no terminal, também registre a alteração no YAML; senão ela desaparece quando o cluster é destruído.
3. Faça commit/push ao GitHub no seu computador ou pela interface web. Na sessão seguinte, use `git clone`/`git pull`, `bash restore.sh` e `bash validate.sh`.

## Limitações importantes

- Não recupera logs antigos, VMs, IPs, ClusterIPs, certificados, objetos dinâmicos, PersistentVolumes nem dados sem backup externo. Kubernetes será recriado pelo KillerCoda; o pacote restaura **aplicações**.
- Não instala Cilium, etcd, CoreDNS, kubelet, containerd ou control plane — isso vem do cenário do KillerCoda.
- Metrics Server é uma dependência **opcional** para `kubectl top`; veja `docs/METRICS-SERVER.md`. Não desativamos TLS automaticamente.
- Não inclui Secrets, service account tokens, kubeconfig, certificados, senhas ou credenciais. Nunca versionar esses arquivos.
- O laboratório é para experimentos, não um manifesto pronto para produção. As imagens não estão fixadas por digest e o container Python roda com defaults de usuário; em produção, revisar imagens, isolamento e políticas de segurança.
- Manter somente workloads leves: o cenário observado tem **1 vCPU e aproximadamente 2.2 GiB de RAM**. Não instale Istio completo sem avaliar recursos.

## Limpeza opcional

```bash
kubectl delete namespace sre-release-lab sre-cpu-lab
```

**Atenção:** isso apaga todos os recursos nesses namespaces, inclusive recursos adicionais que você tenha criado.
