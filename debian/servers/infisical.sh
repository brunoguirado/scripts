#!/usr/bin/env bash

# Infisical Self-Hosted Standalone Installation Script for LXC (Debian/Ubuntu)
# Role: Senior DevSecOps Engineer
# Architecture: External Postgres & Redis
# Constraints: 512MB RAM Optimization
# Recent Improvements:
# - Granular RDS/Redis config prompts with auto-URL construction.
# - Pre-flight credential validation via native tools (psql/redis-cli).
# - Portable user switching (works on minimal LXC without sudo).
# - Native Linux Package deployment via infisical-core

set -euo pipefail

# --- Configuration & Defaults ---
export DEBIAN_FRONTEND=noninteractive
LOG_FILE="/var/log/infisical-install.log"
# The native package now uses a Ruby config file:
CONF_FILE="/etc/infisical/infisical.rb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (or with sudo)."
    fi
}

generate_hex() {
    openssl rand -hex 16
}

generate_base64() {
    openssl rand -base64 32
}

# --- Installation Steps ---

install_dependencies() {
    log "Updating system and installing essential native dependencies..."
    apt-get update && apt-get install -y \
        curl \
        postgresql-client \
        redis-tools \
        | tee -a "$LOG_FILE" || error "Failed to install base dependencies"

    log "Adding official Infisical APT repository..."
    curl -1sLf 'https://artifacts-infisical-core.infisical.com/setup.deb.sh' | bash | tee -a "$LOG_FILE" || error "Failed to add Infisical repository"

    log "Installing Infisical native package (infisical-core)..."
    apt-get update && apt-get install -y infisical-core | tee -a "$LOG_FILE" || error "Failed to install infisical-core package"
}

configure_parameters() {
    echo -e "${YELLOW}--- Infisical Configuration ---${NC}"
    
    # Load existing config if available to allow re-runs
    if [[ -f "$CONF_FILE" ]]; then
        log "Existing configuration file found at ${CONF_FILE}. Loading values..."
        [[ -z "${DB_URL:-}" ]] && DB_URL=$(grep "infisical_core\['DB_CONNECTION_URI'\]" "$CONF_FILE" | awk -F"'" '{print $4}' || echo "")
        [[ -z "${REDIS_URL:-}" ]] && REDIS_URL=$(grep "infisical_core\['REDIS_URL'\]" "$CONF_FILE" | awk -F"'" '{print $4}' || echo "")
        [[ -z "${SITE_URL:-}" ]] && SITE_URL=$(grep "infisical_core\['SITE_URL'\]" "$CONF_FILE" | awk -F"'" '{print $4}' || echo "")
        [[ -z "${ENCRYPTION_KEY:-}" ]] && ENCRYPTION_KEY=$(grep "infisical_core\['ENCRYPTION_KEY'\]" "$CONF_FILE" | awk -F"'" '{print $4}' || echo "")
        [[ -z "${AUTH_SECRET:-}" ]] && AUTH_SECRET=$(grep "infisical_core\['AUTH_SECRET'\]" "$CONF_FILE" | awk -F"'" '{print $4}' || echo "")
    fi

    # --- PostgreSQL Configuration ---
    if [[ -z "${DB_URL:-}" ]]; then
        echo -e "\n${BLUE}[PostgreSQL Configuration]${NC}"
        read -p "Database Host [localhost]: " DB_HOST
        DB_HOST=${DB_HOST:-localhost}
        read -p "Database Port [5432]: " DB_PORT
        DB_PORT=${DB_PORT:-5432}
        read -p "Database User: " DB_USER
        read -s -p "Database Password: " DB_PASS
        echo ""
        read -p "Database Name [infisical]: " DB_NAME
        DB_NAME=${DB_NAME:-infisical}
        
        DB_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    fi

    # --- Redis Configuration ---
    if [[ -z "${REDIS_URL:-}" ]]; then
        echo -e "\n${BLUE}[Redis Configuration]${NC}"
        read -p "Redis Host [localhost]: " REDIS_HOST
        REDIS_HOST=${REDIS_HOST:-localhost}
        read -p "Redis Port [6379]: " REDIS_PORT
        REDIS_PORT=${REDIS_PORT:-6379}
        read -p "Redis User (optional): " REDIS_USER
        read -s -p "Redis Password (optional): " REDIS_PASS
        echo ""
        
        if [[ -n "$REDIS_PASS" ]]; then
            if [[ -n "$REDIS_USER" ]]; then
                REDIS_URL="redis://${REDIS_USER}:${REDIS_PASS}@${REDIS_HOST}:${REDIS_PORT}"
            else
                REDIS_URL="redis::${REDIS_PASS}@${REDIS_HOST}:${REDIS_PORT}"
            fi
        else
            REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT}"
        fi
    fi

    local server_ip=$(hostname -I | awk '{print $1}' || echo "localhost")
    local default_site_url="http://${server_ip}:8080"
    
    if [[ -z "${SITE_URL:-}" ]]; then
        read -p "Enter Infisical Site URL [$default_site_url]: " SITE_URL
        SITE_URL=${SITE_URL:-$default_site_url}
    fi

    if [[ -z "$DB_URL" || -z "$REDIS_URL" || -z "$SITE_URL" ]]; then
        error "Missing required parameters (DB_URL, REDIS_URL, or SITE_URL)"
    fi

    # Auto-generate security keys if not provided
    ENCRYPTION_KEY=${ENCRYPTION_KEY:-$(generate_hex)}
    AUTH_SECRET=${AUTH_SECRET:-$(generate_base64)}
}

validate_connectivity() {
    log "Performing pre-flight connectivity checks..."

    log "Verifying PostgreSQL connection..."
    if ! PGPASSWORD="" psql "$DB_URL" -c "SELECT 1" &>/dev/null; then
        error "Failed to connect to PostgreSQL. Check credentials, host, port, and if the database exists."
    fi
    success "PostgreSQL connection verified."

    log "Verifying Redis connection..."
    if ! redis-cli -u "$REDIS_URL" PING | grep -q "PONG"; then
        error "Failed to connect to Redis. Check host, port, and password if provided."
    fi
    success "Redis connection verified."

    success "Pre-flight checks passed!"
}

setup_conf_file() {
    log "Configuring environment file at $CONF_FILE..."
    
    # Ensure directory exists before writing
    mkdir -p "$(dirname "$CONF_FILE")"
    
    cat <<EOF > "$CONF_FILE"
# Infrastructure
infisical_core['HOST'] = '0.0.0.0'
infisical_core['PORT'] = 8080
infisical_core['DB_CONNECTION_URI'] = '${DB_URL//\'/\\\'}'
infisical_core['REDIS_URL'] = '${REDIS_URL//\'/\\\'}'
infisical_core['SITE_URL'] = '${SITE_URL//\'/\\\'}'

# Security
infisical_core['ENCRYPTION_KEY'] = '${ENCRYPTION_KEY//\'/\\\'}'
infisical_core['AUTH_SECRET'] = '${AUTH_SECRET//\'/\\\'}'
EOF
    chmod 600 "$CONF_FILE"
}

reconfigure_infisical() {
    log "Applying configuration and starting Infisical..."
    infisical-ctl reconfigure | tee -a "$LOG_FILE" || error "infisical-ctl reconfigure failed"
}

final_output() {
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo -e "\n"
    echo -e "${GREEN}####################################################${NC}"
    echo -e "${GREEN}#          INFISICAL INSTALADO COM SUCESSO         #${NC}"
    echo -e "${GREEN}####################################################${NC}"
    echo -e "\n${YELLOW}--- IMPORTANTE: CONFIGURAÇÃO INICIAL ---${NC}"
    echo -e "O usuário master (administrador) deve ser criado no"
    echo -e "primeiro acesso via interface web."
    echo -e "\n${BLUE}Detalhes do Acesso:${NC}"
    echo -e "URL: ${SITE_URL}"
    echo -e "Acesso Interno: http://${IP_ADDRESS}:8080"
    echo -e "\n${YELLOW}Credenciais Geradas (Guarde-as com segurança em $CONF_FILE!):${NC}"
    echo -e "ENCRYPTION_KEY: ${ENCRYPTION_KEY}"
    echo -e "AUTH_SECRET: ${AUTH_SECRET}"
    echo -e "\n${BLUE}Status do Serviço:${NC}"
    infisical-ctl status
    echo -e "\n${BLUE}Logs podem ser acompanhados executando:${NC} infisical-ctl tail"
    echo -e "${GREEN}####################################################${NC}\n"
}

# --- Main Execution ---

main() {
    check_root
    log "Starting Infisical Standalone installation for LXC..."
    
    install_dependencies
    configure_parameters
    validate_connectivity
    setup_conf_file
    reconfigure_infisical
    final_output
}

main "$@"

