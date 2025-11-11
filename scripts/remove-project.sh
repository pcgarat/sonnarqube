#!/bin/bash

# ============================================
# Script para Eliminar Proyectos de SonarQube
# ============================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_CONF="$PROJECT_ROOT/projects.conf"
ENV_FILE="$PROJECT_ROOT/.env"

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

# Función para leer configuración de proyecto desde projects.conf
get_project_config() {
    local project_key=$1
    local config_key=$2
    
    if [ ! -f "$PROJECTS_CONF" ]; then
        return 1
    fi
    
    # Buscar la sección del proyecto
    local in_section=0
    while IFS= read -r line; do
        # Ignorar comentarios y líneas vacías
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Detectar inicio de sección
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            if [[ "$line" =~ \[${project_key}\] ]]; then
                in_section=1
            else
                in_section=0
            fi
            continue
        fi
        
        # Leer configuración dentro de la sección
        if [ $in_section -eq 1 ]; then
            if [[ "$line" =~ ^[[:space:]]*${config_key}= ]]; then
                echo "$line" | sed "s/^[[:space:]]*${config_key}=//" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
                return 0
            fi
        fi
    done < "$PROJECTS_CONF"
    
    return 1
}

# Función para verificar que un proyecto existe
project_exists_in_conf() {
    local project_key=$1
    if [ ! -f "$PROJECTS_CONF" ]; then
        return 1
    fi
    grep -q "^\[$project_key\]" "$PROJECTS_CONF"
}

# Función para eliminar proyecto de SonarQube vía API
delete_project_from_sonarqube() {
    local project_key=$1
    local token=$2
    
    if [ -z "$token" ]; then
        return 1
    fi
    
    local sonar_url=$(get_env_value SONAR_HOST_URL http://localhost:9000)
    
    # Verificar que SonarQube está disponible
    if ! curl -s -f "$sonar_url/api/system/status" > /dev/null 2>&1; then
        return 1
    fi
    
    # Eliminar proyecto usando la API de SonarQube
    local response=$(curl -s -w "\n%{http_code}" -u "$token:" \
        -X POST "$sonar_url/api/projects/delete" \
        -d "project=$project_key" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        return 0
    elif echo "$body" | grep -q "not found"; then
        # El proyecto no existe en SonarQube, no es un error
        return 0
    else
        return 1
    fi
}

# Función para eliminar proyecto de projects.conf de forma robusta
remove_project_from_conf() {
    local project_key=$1
    
    if [ ! -f "$PROJECTS_CONF" ]; then
        return 1
    fi
    
    # Crear archivo temporal
    local temp_file=$(mktemp)
    local in_section=false
    local section_found=false
    
    # Procesar cada línea del archivo projects.conf
    while IFS= read -r line || [ -n "$line" ]; do
        # Detectar inicio de sección del proyecto a eliminar
        if [[ "$line" =~ ^\[${project_key}\] ]]; then
            in_section=true
            section_found=true
            # No añadir esta línea (eliminar la sección)
            continue
        fi
        
        # Detectar inicio de otra sección
        if [[ "$line" =~ ^\[.*\] ]]; then
            # Si estábamos en la sección a eliminar, ahora estamos fuera
            if [ "$in_section" = true ]; then
                in_section=false
            fi
            # Añadir la nueva sección
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # Añadir línea si no estamos en la sección a eliminar
        if [ "$in_section" = false ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$PROJECTS_CONF"
    
    # Si no se encontró la sección, no hacer cambios
    if [ "$section_found" = false ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Reemplazar archivo original
    mv "$temp_file" "$PROJECTS_CONF"
    
    # Limpiar líneas vacías múltiples al final del archivo (opcional)
    # Esto mantiene el archivo limpio pero no es crítico
    if [ -f "$PROJECTS_CONF" ]; then
        # Eliminar líneas vacías al final
        while [ -s "$PROJECTS_CONF" ] && [ -z "$(tail -c 1 "$PROJECTS_CONF")" ] || [ "$(tail -c 1 "$PROJECTS_CONF")" = $'\n' ]; do
            truncate -s -1 "$PROJECTS_CONF" 2>/dev/null || sed -i '$ { /^$/d; }' "$PROJECTS_CONF" 2>/dev/null || break
        done
    fi
    
    return 0
}

# Función principal
main() {
    local project_key=$1
    local delete_from_sonar=${2:-false}
    
    if [ -z "$project_key" ]; then
        echo -e "${RED}Error: Debes especificar la clave del proyecto${NC}"
        echo ""
        echo "Uso: $0 <project_key> [--delete-from-sonar]"
        echo ""
        echo "Opciones:"
        echo "  project_key          Clave del proyecto a eliminar"
        echo "  --delete-from-sonar  También eliminar el proyecto de SonarQube (requiere token)"
        echo ""
        echo "Ejemplo:"
        echo "  $0 mi-proyecto"
        echo "  $0 mi-proyecto --delete-from-sonar"
        exit 1
    fi
    
    # Verificar si se debe eliminar de SonarQube
    if [ "$2" = "--delete-from-sonar" ]; then
        delete_from_sonar=true
    fi
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Eliminar Proyecto${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Verificar que el proyecto existe en projects.conf
    if ! project_exists_in_conf "$project_key"; then
        echo -e "${RED}Error: El proyecto '$project_key' no existe en projects.conf${NC}"
        echo -e "${YELLOW}Usa 'make list-projects' para ver los proyectos disponibles${NC}"
        exit 1
    fi
    
    # Obtener información del proyecto
    local project_name=$(get_project_config "$project_key" "project_name")
    local token=$(get_project_config "$project_key" "token")
    
    echo -e "${GREEN}Proyecto encontrado:${NC}"
    echo -e "  ${CYAN}Clave:${NC} $project_key"
    if [ -n "$project_name" ]; then
        echo -e "  ${CYAN}Nombre:${NC} $project_name"
    fi
    echo ""
    
    # Si se debe eliminar de SonarQube
    if [ "$delete_from_sonar" = "true" ]; then
        # Si no hay token del proyecto, intentar usar el token del scanner
        if [ -z "$token" ]; then
            token=$(get_env_value SONARQUBE_SCANNER_TOKEN "")
        fi
        
        if [ -z "$token" ]; then
            echo -e "${YELLOW}⚠ Advertencia: No se encontró token para este proyecto${NC}"
            echo -e "${YELLOW}  No se puede eliminar de SonarQube sin token${NC}"
            echo -e "${YELLOW}  Ejecuta 'make setup-user' para crear un usuario con token automático${NC}"
            read -p "$(echo -e ${CYAN}¿Continuar eliminando solo de projects.conf? [S/n]: ${NC})" confirm
            if [[ "$confirm" =~ ^[Nn]$ ]]; then
                echo -e "${YELLOW}Operación cancelada${NC}"
                exit 0
            fi
            delete_from_sonar=false
        else
            echo -e "${YELLOW}Eliminando proyecto de SonarQube...${NC}"
            if delete_project_from_sonarqube "$project_key" "$token"; then
                echo -e "${GREEN}✓ Proyecto eliminado de SonarQube${NC}"
            else
                echo -e "${YELLOW}⚠ No se pudo eliminar de SonarQube (puede que no exista)${NC}"
            fi
            echo ""
        fi
    fi
    
    # Eliminar de projects.conf
    echo -e "${YELLOW}Eliminando proyecto de projects.conf...${NC}"
    if remove_project_from_conf "$project_key"; then
        echo -e "${GREEN}✓ Proyecto eliminado de projects.conf${NC}"
    else
        echo -e "${RED}Error: No se pudo eliminar de projects.conf${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Proyecto eliminado exitosamente${NC}"
    echo ""
}

# Ejecutar función principal
main "$@"

