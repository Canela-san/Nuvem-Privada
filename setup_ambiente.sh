#!/bin/bash

# ==============================================================================
# Bootstrap Script - Preparação do Servidor Hospedeiro (Pop!_OS / Ubuntu)
# Prepara uma máquina virgem para rodar a infraestrutura do NAS
# ==============================================================================

# Trava de segurança rigorosa
set -euo pipefail

echo "====================================================="
echo " Iniciando instalação de dependências do servidor..."
echo "====================================================="

# 1. Atualiza a lista de pacotes do sistema
echo "[1/4] Atualizando repositórios do Pop!_OS/Ubuntu..."
sudo apt-get update

# 2. Instala os motores, ferramentas de monitoramento e criptografia
# (ffmpeg incluído aqui caso você queira manipular vídeos fora do Docker futuramente)
echo "[2/4] Instalando Docker, PV, ZuluCrypt e utilitários..."
sudo apt-get install -y docker.io docker-compose curl git pv zulucrypt-cli ffmpeg

# 3. Instala a malha de rede segura (Tailscale)
echo "[3/4] Instalando Tailscale (VPN Mesh)..."
curl -fsSL https://tailscale.com/install.sh | sh

# 4. Configura as permissões do Docker para o usuário atual
echo "[4/4] Adicionando o usuário '$USER' ao grupo do Docker..."
sudo usermod -aG docker "$USER"

# 5. Ativa o Docker para iniciar junto com o sistema
sudo systemctl enable --now docker

echo "====================================================="
echo " Instalação concluída com sucesso!"
echo " AVISO: Você precisa REINICIAR o computador (ou encerrar a sessão)"
echo " para que as permissões do grupo Docker entrem em vigor."
echo " Após reiniciar, rode 'sudo tailscale up' para logar na rede."
echo "====================================================="
