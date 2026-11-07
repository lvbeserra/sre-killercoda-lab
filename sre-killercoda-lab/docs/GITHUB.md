# Publicar o laboratório no GitHub

## Método fácil: navegador, sem tokens no KillerCoda
1. Extraia o ZIP no seu computador.
2. Abra https://github.com/new, crie repositório chamado `sre-killercoda-lab` (público ou privado, à sua escolha).
3. Na interface web do repositório, escolha **Add file → Upload files** e envie os arquivos extraídos, mantendo pastas `docs/` e `labs/`.
4. Commit das alterações.
5. Entre em um KillerCoda NOVO e clone `https://github.com/SEU_USUARIO/sre-killercoda-lab.git` se for público.
6. `cd sre-killercoda-lab && bash restore.sh && bash validate.sh`.

Uma alternativa é conectar o GitHub ao ChatGPT para publicar e manter o repositório pelo conector, quando disponível e autorizado.

## Método Git local (no seu PC, não no KillerCoda)
```bash
cd sre-killercoda-lab
git init -b main
git add .
git commit -m "Checkpoint SRE lab: blue-green, drain, cilium"
# Crie o repositório no GitHub (navegador ou GitHub CLI)
git remote add origin https://github.com/SEU_USUARIO/sre-killercoda-lab.git
git push -u origin main
```

## Atualizar no final de cada sessão
- Não faça push de kubeconfig, secrets, certificados, tokens ou logs com dados sensíveis.
- Atualize `lab-completo.yaml` e `docs/PROGRESSO.md` no GitHub (web ou PC).
- Na próxima sessão: clone novamente e `bash restore.sh`.
- Para repositórios privados, use um método de autenticação seguro **fora do terminal público/temporário do lab** ou faça upload dos manifests por meio confiável. Não cole tokens em logs de terminal.
