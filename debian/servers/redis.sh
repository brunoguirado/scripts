#!/usr/bin/env bash

# Redis Optimized Installation & ACL Management Tool
# Role: Senior DevSecOps Engineer

set -euo pipefail

# --- Pre-flight Shell Checks (Safe & Early) ---
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m[ERRO]\033[0m Este script deve ser executado como root (use sudo)."
    exit 1
fi

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERRO: Este script deve ser executado com BASH (use: bash script.sh)." >&2
    exit 1
fi

# --- Configuration ---
LOG_FILE="/var/log/redis-install.log"
REDIS_CONF="/etc/redis/redis.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Helper Functions ---

log() { 
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

success() { 
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

error() { 
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "${msg}" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

generate_password() {
    openssl rand -base64 24
}

detect_memory() {
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_mb=$((total_mem_kb / 1024))
    REDIS_MAX_MEM=$(( (total_mem_mb * 40) / 100 ))
    [[ $REDIS_MAX_MEM -lt 64 ]] && REDIS_MAX_MEM=64
}

get_admin_pass() {
    # Extract requirepass from redis.conf
    if [[ -f "$REDIS_CONF" ]]; then
        ADMIN_PASS=$(grep -E "^requirepass" "$REDIS_CONF" | awk '{print $2}' | tr -d '"')
    else
        ADMIN_PASS=""
    fi
}

# --- Redis Management ---

list_users() {
    get_admin_pass
    echo -e "${BLUE}Usuários cadastrados (ACL List):${NC}"
    redis-cli -a "$ADMIN_PASS" --no-auth-warning ACL LIST
}

manage_user() {
    get_admin_pass
    read -p "Nome do usuário: " USERNAME
    read -s -p "Senha do usuário (vazio para gerar): " USERPASS
    echo
    [[ -z "$USERPASS" ]] && USERPASS=$(generate_password) && echo -e "Senha gerada: ${GREEN}${USERPASS}${NC}"

    # Default permissions for a service user (Infisical style):
    # Access to all keys, but limited commands
    # You can customize these flags based on needs
    # ~* (all keys) &* (all channels) +@all (all commands)
    # Recommended for Infisical: +@all (since it manages its own keys)
    redis-cli -a "$ADMIN_PASS" --no-auth-warning ACL SETUSER "$USERNAME" on ">$USERPASS" "~*" "&*" "+@all"
    success "Usuário $USERNAME criado/atualizado com sucesso."
}

delete_user() {
    get_admin_pass
    read -p "Nome do usuário a excluir: " USERNAME
    if [[ "$USERNAME" == "default" ]]; then
        error "Não é possível excluir o usuário 'default'."
    fi
    redis-cli -a "$ADMIN_PASS" --no-auth-warning ACL DELUSER "$USERNAME"
    success "Usuário $USERNAME removido."
}

user_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Gestão de Usuários Redis (ACL) ===${NC}"
        echo "1) Listar Usuários"
        echo "2) Criar / Alterar Senha de Usuário"
        echo "3) Excluir Usuário"
        echo "4) Voltar / Sair"
        read -p "Escolha uma opção: " OPT
        case $OPT in
            1) list_users ;;
            2) manage_user ;;
            3) delete_user ;;
            4) return 0 ;;
            *) echo "Opção inválida." ;;
        esac
    done
}

# --- Installation Logic ---

install_redis() {
    log "Installing prerequisite packages..."
    apt-get update && apt-get install -y lsb-release curl gpg | tee -a "$LOG_FILE"

    log "Adding official Redis repository..."
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg || true
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

    log "Updating and installing Redis stack..."
    apt-get update
    apt-get install -y redis-server | tee -a "$LOG_FILE" || error "Failed to install redis-server"
    
    detect_memory
    REDIS_PASSWORD=$(generate_password)
    
    # Basic Hardening
    cp "$REDIS_CONF" "${REDIS_CONF}.bak"
    cat <<EOF >> "$REDIS_CONF"
# --- Senior DevSecOps Hardening ---
requirepass ${REDIS_PASSWORD}
maxmemory ${REDIS_MAX_MEM}mb
maxmemory-policy allkeys-lru
appendonly yes
EOF
    sed -i "s/^bind .*/bind 0.0.0.0/g" "$REDIS_CONF"
    
    systemctl enable redis-server
    systemctl restart redis-server || error "Failed to start Redis"
    
    success "Redis instalado com senha admin: ${REDIS_PASSWORD}"
}

# --- Main ---

main() {
    echo -e "${BLUE}Iniciando Ferramenta de Gestão Redis...${NC}"
    
    if command -v redis-server &>/dev/null; then
        echo -e "${GREEN}Instalação do Redis detectada!${NC}"
        user_menu
    else
        echo -e "${YELLOW}Redis não encontrado. Iniciando instalação...${NC}"
        install_redis
        echo -e "${BLUE}Instalação concluída. Deseja realizar a gestão de usuários agora?${NC}"
        user_menu
    fi
}

main "$@"
