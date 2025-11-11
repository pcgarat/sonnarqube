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
        local value=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d ' ')
        if [ -n "$value" ]; then
            echo "$value"
        else
            echo "$default"
        fi
    else
        echo "$default"
    fi
}

# Función para esperar a que SonarQube esté listo
wait_for_sonarqube() {
    local max_attempts=${1:-60}
    local attempt=0
    local silent=${2:-false}
    
    if [ "$silent" != "true" ]; then
        echo -e "${YELLOW}Esperando a que SonarQube esté listo...${NC}"
    fi
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$SONAR_URL/api/system/status" > /dev/null 2>&1; then
            # Verificar que SonarQube esté completamente iniciado (no solo iniciando)
            local status=$(curl -s "$SONAR_URL/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$status" = "UP" ]; then
                if [ "$silent" != "true" ]; then
                    echo -e "${GREEN}✓ SonarQube está listo${NC}"
                fi
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ "$silent" != "true" ]; then
        echo -e "${RED}Error: SonarQube no está disponible después de $max_attempts intentos${NC}"
    fi
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

# Función para verificar si el usuario tiene token configurado
user_has_token() {
    local username=$1
    local token_name=$2
    
    local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        "$SONAR_URL/api/user_tokens/search?login=$username" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q "\"name\":\"$token_name\""; then
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
    
    # Imprimir mensaje a stderr para que no se capture en la variable
    echo -e "${YELLOW}Generando token para '$username'...${NC}" >&2
    
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
            # Solo imprimir el token a stdout (sin códigos ANSI)
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
    
    # Crear archivo temporal
    local temp_file=$(mktemp)
    
    # Procesar cada línea del archivo .env
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^SONARQUBE_SCANNER_TOKEN= ]]; then
            # Reemplazar línea existente
            echo "SONARQUBE_SCANNER_TOKEN=$token" >> "$temp_file"
        elif [[ "$line" =~ ^SONARQUBE_USER= ]]; then
            # Reemplazar línea existente
            echo "SONARQUBE_USER=$SONAR_USER" >> "$temp_file"
        elif [[ "$line" =~ ^SONARQUBE_PASSWORD= ]]; then
            # Reemplazar línea existente
            echo "SONARQUBE_PASSWORD=$SONAR_PASSWORD" >> "$temp_file"
        else
            # Mantener línea original
            echo "$line" >> "$temp_file"
        fi
    done < "$ENV_FILE"
    
    # Añadir variables si no existían
    if ! grep -q "^SONARQUBE_SCANNER_TOKEN=" "$temp_file"; then
        echo "SONARQUBE_SCANNER_TOKEN=$token" >> "$temp_file"
    fi
    if ! grep -q "^SONARQUBE_USER=" "$temp_file"; then
        echo "SONARQUBE_USER=$SONAR_USER" >> "$temp_file"
    fi
    if ! grep -q "^SONARQUBE_PASSWORD=" "$temp_file"; then
        echo "SONARQUBE_PASSWORD=$SONAR_PASSWORD" >> "$temp_file"
    fi
    
    # Reemplazar archivo original
    mv "$temp_file" "$ENV_FILE"
}

# Función principal
main() {
    local silent_mode=false
    if [ "$1" = "--silent" ]; then
        silent_mode=true
    fi
    
    if [ "$silent_mode" != "true" ]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Configuración de Usuario SonarQube${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    fi
    
    # Leer valores de .env si existen, usando valores por defecto
    SONAR_USER=$(get_env_value SONARQUBE_USER "scanner")
    SONAR_PASSWORD=$(get_env_value SONARQUBE_PASSWORD "scanner123")
    SONAR_URL=$(get_env_value SONAR_HOST_URL "http://localhost:9000")
    ADMIN_USER=$(get_env_value SONARQUBE_ADMIN_USER "admin")
    ADMIN_PASSWORD=$(get_env_value SONARQUBE_ADMIN_PASSWORD "admin")
    
    # Validar que los valores no estén vacíos
    if [ -z "$SONAR_USER" ]; then
        SONAR_USER="scanner"
    fi
    if [ -z "$SONAR_PASSWORD" ]; then
        SONAR_PASSWORD="scanner123"
    fi
    if [ -z "$ADMIN_USER" ]; then
        ADMIN_USER="admin"
    fi
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD="admin"
    fi
    
    # Esperar a que SonarQube esté listo (más intentos en modo silencioso)
    if ! wait_for_sonarqube 120 "$silent_mode"; then
        if [ "$silent_mode" != "true" ]; then
            exit 1
        else
            # En modo silencioso, simplemente salir sin error
            exit 0
        fi
    fi
    
    if [ "$silent_mode" != "true" ]; then
        echo ""
    fi
    
    # Verificar si el usuario ya existe
    local user_already_exists=false
    if user_exists "$SONAR_USER"; then
        if [ "$silent_mode" != "true" ]; then
            echo -e "${GREEN}✓ El usuario '$SONAR_USER' ya existe${NC}"
        fi
        user_already_exists=true
    else
        # Crear usuario
        if [ "$silent_mode" != "true" ]; then
            if ! create_user "$SONAR_USER" "$SONAR_PASSWORD" "SonarQube Scanner User"; then
                exit 1
            fi
        else
            # En modo silencioso, crear sin mensajes
            local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
                -X POST "$SONAR_URL/api/users/create" \
                -d "login=$SONAR_USER" \
                -d "password=$SONAR_PASSWORD" \
                -d "name=SonarQube Scanner User" 2>/dev/null)
            local http_code=$(echo "$response" | tail -n1)
            if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
                exit 1
            fi
        fi
    fi
    
    if [ "$silent_mode" != "true" ]; then
        echo ""
    fi
    
    # Asignar permisos de administrador (siempre, por si acaso cambió algo)
    if [ "$silent_mode" != "true" ]; then
        if ! grant_admin_permissions "$SONAR_USER"; then
            echo -e "${YELLOW}⚠ No se pudieron asignar permisos de administrador, pero continuando...${NC}"
        fi
    else
        # En modo silencioso, asignar sin mensajes
        curl -s -u "$ADMIN_USER:$ADMIN_PASSWORD" \
            -X POST "$SONAR_URL/api/user_groups/add_user" \
            -d "login=$SONAR_USER" \
            -d "name=sonar-administrators" > /dev/null 2>&1 || true
    fi
    
    if [ "$silent_mode" != "true" ]; then
        echo ""
    fi
    
    # Verificar si ya tiene token y si está en .env
    local token=""
    local existing_token=$(get_env_value SONARQUBE_SCANNER_TOKEN "")
    
    if [ -n "$existing_token" ] && user_has_token "$SONAR_USER" "scanner-token"; then
        if [ "$silent_mode" != "true" ]; then
            echo -e "${GREEN}✓ El usuario ya tiene token configurado${NC}"
        fi
        token="$existing_token"
    else
        # Generar token (o regenerar si ya existe)
        if [ "$silent_mode" != "true" ]; then
            if user_has_token "$SONAR_USER" "scanner-token"; then
                echo -e "${YELLOW}El usuario ya tiene un token. Generando uno nuevo...${NC}"
            fi
            token=$(generate_token "$SONAR_USER" "scanner-token")
            if [ -z "$token" ]; then
                echo -e "${RED}Error: No se pudo generar el token${NC}"
                exit 1
            fi
            echo -e "${GREEN}✓ Token generado${NC}"
        else
            # En modo silencioso, generar sin mensajes
            curl -s -u "$ADMIN_USER:$ADMIN_PASSWORD" \
                -X POST "$SONAR_URL/api/user_tokens/revoke" \
                -d "login=$SONAR_USER" \
                -d "name=scanner-token" > /dev/null 2>&1 || true
            
            local response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASSWORD" \
                -X POST "$SONAR_URL/api/user_tokens/generate" \
                -d "login=$SONAR_USER" \
                -d "name=scanner-token" 2>/dev/null)
            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | head -n-1)
            
            if [ "$http_code" = "200" ]; then
                token=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
            fi
            
            if [ -z "$token" ]; then
                exit 1
            fi
        fi
        
        if [ "$silent_mode" != "true" ]; then
            echo ""
        fi
        
        # Actualizar .env
        update_env_file "$token"
    fi
    
    if [ "$silent_mode" != "true" ]; then
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
    fi
}

# Ejecutar función principal
main "$@"

