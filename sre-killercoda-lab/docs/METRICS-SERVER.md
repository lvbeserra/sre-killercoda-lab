# Metrics Server — etapa opcional, não instalada automaticamente

A configuração base do KillerCoda tinha Metrics API ausente. Foi identificada incompatibilidade TLS porque o kubelet apresentava certificado SAN `DNS:controlplane`, mas o Metrics Server consultava `172.30.1.2:10250`.

## Diagnosticar primeiro
```bash
kubectl get apiservice | grep metrics.k8s.io || true
kubectl -n kube-system get deploy metrics-server || true
kubectl -n kube-system get pods | grep metrics-server || true
kubectl top nodes
```

## Instalar a versão do laboratório (só se desejar)
No cenário descartável, após revisar manifesto e compatibilidade:
```bash
curl -fL https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml -o /tmp/metrics-server.yaml
kubectl apply -f /tmp/metrics-server.yaml
kubectl -n kube-system logs deploy/metrics-server --tail=40
```

Se houver falha `x509: ... doesn't contain any IP SANs`, a correção segura é emitir um certificado do kubelet com SAN adequado e cadeia de confiança aceita. A opção `--kubelet-insecure-tls` **enfraquece a validação de identidade do kubelet** e foi utilizada apenas como teste temporário no KillerCoda. Não a automatizamos no restore nem recomendamos para produção.

Com instalação/validação correta, `kubectl top nodes && kubectl top pods -A` passa a funcionar. Metrics Server não é substituto para Prometheus.
