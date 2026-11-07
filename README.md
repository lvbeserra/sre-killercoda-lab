# SRE KillerCoda Lab — entrada rápida

Lab Kubernetes/SRE reproduzível, com Blue-Green, rolling updates, Cilium/eBPF, HTTP e checkpoints Git.

## A cada sessão nova do KillerCoda

No terminal Ubuntu do cenário Kubernetes:

```bash
git clone https://github.com/lvbeserra/sre-killercoda-lab.git
cd sre-killercoda-lab
bash iniciar.sh
```

**O `iniciar.sh` automatiza o setup:** verifica Kubernetes, instala `gh` via `apt` se necessário, abre o login seguro pelo dispositivo (você autoriza no Chrome), configura nome/e-mail Git apenas neste repositório, aplica `lab-completo.yaml`, valida DNS/HTTP e inicia o monitor de checkpoints: um logo no início e novos a cada **50 minutos**.

O `git clone` sozinho **não instala softwares nem executa scripts**. Execute `bash iniciar.sh` em cada nova VM. Como a VM é descartável, o login do GitHub também precisará ser autorizado novamente.

**Importante:** salve no manifesto qualquer alteração feita apenas via `kubectl`; checkpoints versionam arquivos Git e uma captura de status, não o estado completo da VM ou do cluster. Veja [documentação detalhada](sre-killercoda-lab/README.md) e [progresso das aulas](sre-killercoda-lab/docs/PROGRESSO.md).

### Verificar os checkpoints
```bash
tail -30 /tmp/sre-checkpoints.log
git status -sb
```

Um `git push` só está confirmado quando o log diz `SUCESSO: checkpoint publicado no GitHub.`. Se houver falha de rede, autenticação ou conflito Git, o checkpoint poderá ficar só na VM.

Não envie credenciais, kubeconfig, Secrets ou tokens ao GitHub. O Metrics Server é opcional e não é instalado por padrão por exigir avaliação do TLS do kubelet neste lab.
