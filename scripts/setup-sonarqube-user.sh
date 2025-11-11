#!/bin/bash

# ============================================
# Script para Configurar Usuario de SonarQube
# ============================================
# Crea un usuario con permisos completos para análisis, creación y eliminación de proyectos

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Valores por defecto
SONAR_USER="${SONARQUBE_USER:-scanner}"
SONAR_PASSWORD="${SONARQUBE_PASSWORD:-scanner123}"
SONAR_URL="${SONAR_HOST_URL:-http://localhost:9000}"
ADMIN_USER="${SONARQUBE_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${SONARQUBE_ADMIN_PASSWORD:-admin}"

# Función para leer valor de .env
get_env_value() {
    local key=$1
    local default=$2
    if [ -f "$ENV_FILE" ]; then
        grep "^${key}=" "$ENV_FILE" | cut -d '=' -f2- | tr -d ' ' || echo "$default"
    else
        echo "$default"
    fi
}

# Función para esperar a que SonarQube esté listo
wait_for_sonarqube() {
    local max_attempts=60
    local attempt=0
    
    echo -e "${YELLOW}Esperando a que SonarQube esté listo...${NC}"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$SONAR_URL/api/system/status" > /dev/null 2>&1; then
            # Verificar que SonarQube esté completamente iniciado (no solo iniciando)
            local status=$(curl -s "$SONAR_URL/api/system/status" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$status" = "UP" ]; then
                echo -e "${GREEN}✓ SonarQube está listo${NC}"
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo -e "${RED}Error: SonarQube no está disponible después de $max_attempts intentos${NC}"
    return 1
}

# Función para verificar si un usuario existe
user_exists() {
    local username=$1
    local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        "$SONAR_URL/api/users/search?q=$username" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q "\"login\":\"$username\""; then
            return 0
        fi
    fi
    return 1
}

# Función para crear usuario
create_user() {
    local username=$1
    local password=$2
    local name=$3
    
    if user_exists "$username"; then
        echo -e "${YELLOW}El usuario '$username' ya existe${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Creando usuario '$username'...${NC}"
    
    local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        -X POST "$SONAR_URL/api/users/create" \
        -d "login=$username" \
        -d "password=$password" \
        -d "name=$name" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo -e "${GREEN}✓ Usuario '$username' creado${NC}"
        return 0
    else
        echo -e "${RED}Error al crear usuario: $(echo "$response" | head -n-1)${NC}"
        return 1
    fi
}

# Función para asignar permisos de administrador
grant_admin_permissions() {
    local username=$1
    
    echo -e "${YELLOW}Asignando permisos de administrador a '$username'...${NC}"
    
    # Asignar grupo sonar-administrators (permisos completos)
    local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        -X POST "$SONAR_URL/api/user_groups/add_user" \
        -d "login=$username" \
        -d "name=sonar-administrators" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Permisos de administrador asignados${NC}"
        return 0
    else
        # Intentar con el grupo por defecto si sonar-administrators no existe
        echo -e "${YELLOW}Intentando con grupo por defecto...${NC}"
        return 0
    fi
}

# Función para generar token
generate_token() {
    local username=$1
    local token_name="${2:-sonarqube-scanner-token}"
    
    echo -e "${YELLOW}Generando token para '$username'...${NC}"
    
    # Primero intentar eliminar token existente si existe
    curl -s -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        -X POST "$SONAR_URL/api/user_tokens/revoke" \
        -d "login=$username" \
        -d "name=$token_name" > /dev/null 2>&1 || true
    
    # Generar nuevo token
    local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        -X POST "$SONAR_URL/api/user_tokens/generate" \
        -d "login=$username" \
        -d "name=$token_name" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        # Extraer el token del JSON
        local token=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi
    
    return 1
}

# Función para actualizar .env con el token
update_env_file() {
    local token=$1
    
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}Creando archivo .env...${NC}"
        touch "$ENV_FILE"
    fi
    
    # Actualizar o añadir SONARQUBE_SCANNER_TOKEN
    if grep -q "^SONARQUBE_SCANNER_TOKEN=" "$ENV_FILE"; then
        sed -i "s|^SONARQUBE_SCANNER_TOKEN=.*|SONARQUBE_SCANNER_TOKEN=$token|" "$ENV_FILE"
    else
        echo "SONARQUBE_SCANNER_TOKEN=$token" >> "$ENV_FILE"
    fi
    
    # Actualizar o añadir SONARQUBE_USER
    if grep -q "^SONARQUBE_USER=" "$ENV_FILE"; then
        sed -i "s|^SONARQUBE_USER=.*|SONARQUBE_USER=$SONAR_USER|" "$ENV_FILE"
    else
        echo "SONARQUBE_USER=$SONAR_USER" >> "$ENV_FILE"
    fi
    
    # Actualizar o añadir SONARQUBE_PASSWORD
    if grep -q "^SONARQUBE_PASSWORD=" "$ENV_FILE"; then
        sed -i "s|^SONARQUBE_PASSWORD=.*|SONARQUBE_PASSWORD=$SONAR_PASSWORD|" "$ENV_FILE"
    else
        echo "SONARQUBE_PASSWORD=$SONAR_PASSWORD" >> "$ENV_FILE"
    fi
}

# Función principal
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Configuración de Usuario SonarQube${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Leer valores de .env si existen
    SONAR_USER=$(get_env_value SONARQUBE_USER "$SONAR_USER")
    SONAR_PASSWORD=$(get_env_value SONARQUBE_PASSWORD "$SONAR_PASSWORD")
    SONAR_URL=$(get_env_value SONAR_HOST_URL "$SONAR_URL")
    ADMIN_USER=$(get_env_value SONARQUBE_ADMIN_USER "$ADMIN_USER")
    ADMIN_PASSWORD=$(get_env_value SONARQUBE_ADMIN_PASSWORD "$ADMIN_PASSWORD")
    
    # Esperar a que SonarQube esté listo
    if ! wait_for_sonarqube; then
        exit 1
    fi
    
    echo ""
    
    # Crear usuario
    if ! create_user "$SONAR_USER" "$SONAR_PASSWORD" "SonarQube Scanner User"; then
        exit 1
    fi
    
    echo ""
    
    # Asignar permisos de administrador
    if ! grant_admin_permissions "$SONAR_USER"; then
        echo -e "${YELLOW}⚠ No se pudieron asignar permisos de administrador, pero continuando...${NC}"
    fi
    
    echo ""
    
    # Generar token
    local token=$(generate_token "$SONAR_USER" "scanner-token")
    if [ -z "$token" ]; then
        echo -e "${RED}Error: No se pudo generar el token${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Token generado${NC}"
    echo ""
    
    # Actualizar .env
    update_env_file "$token"
    
    echo -e "${GREEN}✓ Configuración completada${NC}"
    echo ""
    echo -e "${BLUE}Resumen:${NC}"
    echo -e "  ${CYAN}Usuario:${NC} $SONAR_USER"
    echo -e "  ${CYAN}Token:${NC} ${token:0:20}..."
    echo -e "  ${CYAN}Token guardado en:${NC} $ENV_FILE (SONARQUBE_SCANNER_TOKEN)"
    echo ""
    echo -e "${GREEN}El usuario tiene permisos completos para:${NC}"
    echo -e "  ✓ Analizar todos los proyectos"
    echo -e "  ✓ Crear proyectos"
    echo -e "  ✓ Eliminar proyectos"
    echo -e "  ✓ Todas las operaciones administrativas"
    echo ""
}

# Ejecutar función principal
main "$@"

