#!/bin/bash

# ==============================================================================
# Script de Manutenção do Servidor Nextcloud
# Focado em resiliência, segurança e logs de operação.
# ==============================================================================

# Trava de Engenharia: O script é abortado imediatamente se qualquer comando falhar,
# se uma variável não existir, ou se um erro ocorrer dentro de um "pipe" (|).
set -euo pipefail

# Variáveis Globais
PROJECT_DIR="/home/canela/git/Nuvem-Privada"
DATA_HORA=$(date '+%Y-%m-%d %H:%M:%S')

echo "====================================================="
echo "[$DATA_HORA] Iniciando rotina de manutenção do NAS..."
echo "====================================================="

# Navega para a pasta do projeto (falha se a pasta não existir graças ao set -e)
cd "$PROJECT_DIR"

# ------------------------------------------------------------------------------
# OPERAÇÃO 1: Escaneamento de Arquivos Físicos (Seu comando original)
# ------------------------------------------------------------------------------
echo "-> Sincronizando discos físicos com o banco de dados MariaDB..."
# A flag -T desabilita a alocação de terminal virtual. É OBRIGATÓRIA para 
# scripts automatizados rodarem perfeitamente no Docker em segundo plano.
docker compose exec -T --user www-data app php occ files:scan --all

# ------------------------------------------------------------------------------
# OPERAÇÃO 2: Limpeza de Cache (Exemplo de operação útil adicional)
# ------------------------------------------------------------------------------
# O Nextcloud acumula lixo no banco de dados com o tempo. Isso limpa a sujeira.
echo "-> Limpando arquivos de cache antigos e lixeiras expiradas..."
docker compose exec -T --user www-data app php occ trashbin:cleanup --all-users
docker compose exec -T --user www-data app php occ versions:cleanup

# ------------------------------------------------------------------------------
# OPERAÇÃO 3: Aqui você pode adicionar backups futuros, etc.
# ------------------------------------------------------------------------------
# echo "-> Fazendo dump do banco de dados..."

echo "====================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Manutenção concluída com sucesso!"
echo "====================================================="
