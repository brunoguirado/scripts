#!/bin/bash

# -------------------------------------------------------------------------------
# Nome: Install PostgreSQL
# -------------------------------------------------------------------------------

set -e

# Cores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== PostgreSQL ===${NC}"

# 1. Seleção de Versão
echo "Selecione a versão:"
echo "1) PostgreSQL 14"
echo "2) PostgreSQL 16"
echo "3) PostgreSQL 18"
read -p "Opção [1-3]: " opt

case $opt in
    1) PG_VERSION="14" ;;
    2) PG_VERSION="16" ;;
    3) PG_VERSION="18" ;;
    *) echo "Opção inválida"; exit 1 ;;
esac

# 2. Configuração de Rede Dinâmica
echo -e "\n${YELLOW}Configuração de Acesso HBA:${NC}"
read -p "Informe a rede permitida (ex: 192.168.50.0/24) [Default: 0.0.0.0/0]: " USER_NET
ALLOWED_NETWORK=${USER_NET:-"0.0.0.0/0"} # Se vazio, usa 0.0.0.0/0

# 3. Entrada Segura de Senha
echo -e "\n${GREEN}"
read -s -p "Defina a senha para o usuário 'postgres': " DB_PASSWORD
echo -e "\n${NC}"

# 4. Preparação e Locales
echo -e "${BLUE}[1/5] Configurando Locales (en_US.UTF-8)...${NC}"
apt update && apt install -y curl ca-certificates gnupg lsb-release locales
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# 5. Repositório Oficial PGDG
echo -e "${BLUE}[2/5] Adicionando repositório PGDG...${NC}"
install -m 0755 -d /etc/apt/keyrings
curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg
echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# 6. Instalação
echo -e "${BLUE}[3/5] Instalando PostgreSQL $PG_VERSION...${NC}"
apt update
apt install -y postgresql-$PG_VERSION postgresql-server-dev-$PG_VERSION libpq-dev

# 7. Configuração de Rede (HBA & Listen)
echo -e "${BLUE}[4/5] Aplicando regras de rede para $ALLOWED_NETWORK...${NC}"
CONF_FILE="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
HBA_FILE="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# Libera o listen_addresses globalmente
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $CONF_FILE

# Adiciona a rede escolhida no final do pg_hba.conf
echo "host    all             all             $ALLOWED_NETWORK         scram-sha-256" >> $HBA_FILE

# 8. Finalização
echo -e "${BLUE}[5/5] Reiniciando e definindo credenciais...${NC}"
systemctl restart postgresql
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '$DB_PASSWORD';\""

echo -e "${GREEN}✅ Deploy concluído com sucesso!${NC}"
echo -e "Versão: $PG_VERSION | Rede: $ALLOWED_NETWORK"
