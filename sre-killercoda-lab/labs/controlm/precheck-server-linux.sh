#!/usr/bin/env bash
# Control-M Server: inventario PRE-INSTALACAO somente leitura.
# Nao instala software, nao altera kernel, users, services, certificados ou firewall.
# Executar apenas em VM Linux autorizada de laboratorio, nao no KillerCoda pequeno.
set -uo pipefail
have(){ command -v "$1" >/dev/null 2>&1; }
run(){ printf "\n=== %s ===\n" "$1"; shift; "$@" 2>&1 || true; }

echo "CONTROL-M SERVER 9.0.27 - PREFLIGHT READ-ONLY"
echo "Ambiente: $(date -Is) | Host: $(hostname -f 2>/dev/null || hostname)"
run "Sistema" cat /etc/os-release
run "Arquitetura" uname -m
run "Kernel" uname -r
run "CPU" nproc
run "Memoria (MiB)" free -m
run "Discos" df -hT
run "Blocos" lsblk -f
run "Swap" swapon --show
run "NTP" timedatectl
if have chronyc; then run "Chrony" chronyc tracking; fi
run "Interfaces" ip -br a
run "Hostname" hostname -f
if have getent; then run "Resolucao FQDN" getent hosts "$(hostname -f 2>/dev/null || hostname)"; fi
run "Portas em escuta" ss -lntp
if have firewall-cmd; then run "Firewall" firewall-cmd --list-all; fi
if have getenforce; then run "SELinux" getenforce; fi
if have java; then run "Java" java -version; fi
run "Conta ctmuser" id ctmuser
run "Grupo ctmgrp" getent group ctmgrp

echo
echo "=== RESUMO BASICO ==="
arch=$(uname -m)
cpu=$(nproc)
mem=$(awk '/MemTotal/{print int($2 / 1024)}' /proc/meminfo)
printf 'Arquitetura: %s (requisito x86_64)\n' "$arch"
printf 'vCPU: %s (referencia minima BMC: 4)\n' "$cpu"
printf 'RAM fisica: %s MiB (Server com DB local: referencia 12 GiB)\n' "$mem"
[ "$arch" = x86_64 ] || echo "ALERTA: arquitetura nao compativel com referencia x86_64."
[ "$cpu" -ge 4 ] || echo "ALERTA: menos de 4 vCPU."
[ "$mem" -ge 12288 ] || echo "ALERTA: RAM abaixo de 12GiB para Server e PostgreSQL BMC local."
echo "PENDENTE: confirmar SO/patch suportados, 40GB livres no volume de instalacao,"
echo "CheckReq da midia BMC, swap, Java homologado, ulimit, portas e certificado TLS."
echo "INFO: este comando NAO executa o CheckReq oficial da BMC."
