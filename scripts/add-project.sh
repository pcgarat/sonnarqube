#!/bin/bash

# ============================================
# Script para Añadir Proyectos a SonarQube
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
PROJECTS_CONF_EXAMPLE="$PROJECT_ROOT/projects.conf.example"
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

# Función para crear proyecto en SonarQube vía API
create_project_in_sonarqube() {
    local project_key=$1
    local project_name=$2
    local token=$3
    
    if [ -z "$token" ]; then
        return 1
    fi
    
    local sonar_url=$(get_env_value SONAR_HOST_URL http://localhost:9000)
    
    # Verificar que SonarQube está disponible
    if ! curl -s -f "$sonar_url/api/system/status" > /dev/null 2>&1; then
        return 1
    fi
    
    # Crear proyecto usando la API de SonarQube
    local response=$(curl -s -w "\n%{http_code}" -u "$token:" \
        -X POST "$sonar_url/api/projects/create" \
        -d "project=$project_key" \
        -d "name=$project_name" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        return 0
    elif echo "$body" | grep -q "already exists"; then
        # El proyecto ya existe, no es un error
        return 0
    else
        return 1
    fi
}

# Función para validar que un proyecto no existe ya
project_exists() {
    local project_key=$1
    if [ -f "$PROJECTS_CONF" ]; then
        grep -q "^\[$project_key\]" "$PROJECTS_CONF"
    else
        return 1
    fi
}

# Función para validar ruta absoluta
is_absolute_path() {
    [[ "$1" = /* ]]
}

# Función para auto-detectar lenguaje
detect_language() {
    local project_path=$1
    
    if [ ! -d "$project_path" ]; then
        echo ""
        return
    fi
    
    # Detectar por archivos característicos
    if [ -f "$project_path/pom.xml" ] || [ -f "$project_path/build.gradle" ] || [ -f "$project_path/build.gradle.kts" ]; then
        echo "java"
    elif [ -f "$project_path/package.json" ]; then
        echo "js"
    elif [ -f "$project_path/requirements.txt" ] || [ -f "$project_path/setup.py" ] || [ -f "$project_path/pyproject.toml" ]; then
        echo "py"
    elif [ -f "$project_path/Cargo.toml" ]; then
        echo "rust"
    elif [ -f "$project_path/go.mod" ]; then
        echo "go"
    elif [ -f "$project_path/composer.json" ]; then
        echo "php"
    elif [ -f "$project_path/Gemfile" ]; then
        echo "ruby"
    else
        echo ""
    fi
}

# Función principal
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Añadir Proyecto a SonarQube${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Crear projects.conf si no existe
    if [ ! -f "$PROJECTS_CONF" ]; then
        if [ -f "$PROJECTS_CONF_EXAMPLE" ]; then
            echo -e "${YELLOW}Creando projects.conf desde el ejemplo...${NC}"
            cp "$PROJECTS_CONF_EXAMPLE" "$PROJECTS_CONF"
            # Eliminar el contenido de ejemplo
            echo "# ============================================" > "$PROJECTS_CONF"
            echo "# Configuración de Proyectos para SonarQube" >> "$PROJECTS_CONF"
            echo "# ============================================" >> "$PROJECTS_CONF"
            echo "" >> "$PROJECTS_CONF"
        else
            echo -e "${YELLOW}Creando projects.conf...${NC}"
            touch "$PROJECTS_CONF"
        fi
    fi
    
    # Solicitar project_key
    while true; do
        echo -e "${CYAN}Clave del proyecto (project_key):${NC}"
        echo -e "${YELLOW}  (Debe ser único en SonarQube, sin espacios, ej: mi-proyecto)${NC}"
        read -r project_key
        
        if [ -z "$project_key" ]; then
            echo -e "${RED}Error: La clave del proyecto no puede estar vacía${NC}"
            continue
        fi
        
        if [[ "$project_key" =~ [[:space:]] ]]; then
            echo -e "${RED}Error: La clave del proyecto no puede contener espacios${NC}"
            continue
        fi
        
        if project_exists "$project_key"; then
            echo -e "${RED}Error: Ya existe un proyecto con la clave '$project_key'${NC}"
            echo -e "${YELLOW}Usa 'make list-projects' para ver los proyectos existentes${NC}"
            continue
        fi
        
        break
    done
    
    echo ""
    
    # Solicitar project_name
    while true; do
        echo -e "${CYAN}Nombre del proyecto (project_name):${NC}"
        echo -e "${YELLOW}  (Nombre descriptivo, ej: Mi Proyecto Java)${NC}"
        read -r project_name
        
        if [ -z "$project_name" ]; then
            echo -e "${RED}Error: El nombre del proyecto no puede estar vacío${NC}"
            continue
        fi
        
        break
    done
    
    echo ""
    
    # Solicitar project_path
    while true; do
        echo -e "${CYAN}Ruta absoluta al proyecto (project_path):${NC}"
        echo -e "${YELLOW}  (Debe ser una ruta absoluta, ej: /home/usuario/proyectos/mi-proyecto)${NC}"
        read -r project_path
        
        if [ -z "$project_path" ]; then
            echo -e "${RED}Error: La ruta del proyecto no puede estar vacía${NC}"
            continue
        fi
        
        if ! is_absolute_path "$project_path"; then
            echo -e "${RED}Error: La ruta debe ser absoluta (debe comenzar con /)${NC}"
            continue
        fi
        
        if [ ! -d "$project_path" ]; then
            echo -e "${YELLOW}⚠ Advertencia: El directorio '$project_path' no existe${NC}"
            read -p "¿Continuar de todas formas? (s/N): " confirm
            if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
                continue
            fi
        fi
        
        break
    done
    
    echo ""
    
    # Auto-detectar lenguaje
    detected_language=$(detect_language "$project_path")
    
    # Solicitar language
    if [ -n "$detected_language" ]; then
        echo -e "${GREEN}✓ Lenguaje detectado: $detected_language${NC}"
        echo -e "${CYAN}Lenguaje del proyecto (language):${NC}"
        echo -e "${YELLOW}  (Presiona Enter para usar '$detected_language' o escribe otro)${NC}"
        read -r language
        language=${language:-$detected_language}
    else
        echo -e "${CYAN}Lenguaje del proyecto (language):${NC}"
        echo -e "${YELLOW}  (Opcional, ej: java, js, py, php, go, rust, ruby)${NC}"
        read -r language
    fi
    
    echo ""
    
    # Solicitar token
    echo -e "${CYAN}Token de autenticación de SonarQube (token):${NC}"
    echo -e "${YELLOW}  (Opcional, puedes pasarlo con --token al analizar)${NC}"
    echo -e "${YELLOW}  Para obtener un token:${NC}"
    echo -e "${YELLOW}    1. Ve a http://localhost:9000${NC}"
    echo -e "${YELLOW}    2. My Account > Security${NC}"
    echo -e "${YELLOW}    3. Genera un nuevo token${NC}"
    read -r token
    
    echo ""
    
    # Mostrar resumen
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Resumen de Configuración${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Clave:${NC} $project_key"
    echo -e "${GREEN}Nombre:${NC} $project_name"
    echo -e "${GREEN}Ruta:${NC} $project_path"
    if [ -n "$language" ]; then
        echo -e "${GREEN}Lenguaje:${NC} $language"
    fi
    if [ -n "$token" ]; then
        echo -e "${GREEN}Token:${NC} ${token:0:20}..."
    else
        echo -e "${YELLOW}Token:${NC} (no especificado)"
    fi
    echo ""
    
    # Confirmar
    read -p "$(echo -e ${CYAN}¿Añadir este proyecto? [S/n]: ${NC})" confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        exit 0
    fi
    
    # Añadir al archivo
    echo "" >> "$PROJECTS_CONF"
    echo "[$project_key]" >> "$PROJECTS_CONF"
    echo "project_key=$project_key" >> "$PROJECTS_CONF"
    echo "project_name=$project_name" >> "$PROJECTS_CONF"
    echo "project_path=$project_path" >> "$PROJECTS_CONF"
    if [ -n "$language" ]; then
        echo "language=$language" >> "$PROJECTS_CONF"
    fi
    if [ -n "$token" ]; then
        echo "token=$token" >> "$PROJECTS_CONF"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Proyecto añadido exitosamente a projects.conf${NC}"
    echo ""
    
    # Intentar crear el proyecto en SonarQube si hay token
    # Si no hay token del proyecto, intentar usar el token del scanner
    if [ -z "$token" ]; then
        token=$(get_env_value SONARQUBE_SCANNER_TOKEN "")
    fi
    
    if [ -n "$token" ]; then
        echo -e "${YELLOW}Creando proyecto en SonarQube...${NC}"
        if create_project_in_sonarqube "$project_key" "$project_name" "$token"; then
            echo -e "${GREEN}✓ Proyecto creado en SonarQube${NC}"
            echo ""
            echo -e "${BLUE}Próximos pasos:${NC}"
            echo -e "  1. Verifica la configuración: ${CYAN}make list-projects${NC}"
            echo -e "  2. El proyecto ya está disponible en SonarQube: ${CYAN}http://localhost:9000/dashboard?id=$project_key${NC}"
            echo -e "  3. Analiza el proyecto: ${CYAN}make analyze PROJECT=$project_key${NC}"
        else
            echo -e "${YELLOW}⚠ No se pudo crear el proyecto en SonarQube automáticamente${NC}"
            echo -e "${YELLOW}  (El proyecto se creará automáticamente al ejecutar el primer análisis)${NC}"
            echo ""
            echo -e "${BLUE}Próximos pasos:${NC}"
            echo -e "  1. Verifica la configuración: ${CYAN}make list-projects${NC}"
            echo -e "  2. Analiza el proyecto para crearlo en SonarQube: ${CYAN}make analyze PROJECT=$project_key${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No se proporcionó token. El proyecto se creará en SonarQube al ejecutar el primer análisis.${NC}"
        echo ""
        echo -e "${BLUE}Próximos pasos:${NC}"
        echo -e "  1. Verifica la configuración: ${CYAN}make list-projects${NC}"
        echo -e "  2. Analiza el proyecto (esto creará el proyecto en SonarQube): ${CYAN}make analyze PROJECT=$project_key --token=TU_TOKEN${NC}"
    fi
    echo ""
}

# Ejecutar función principal
main "$@"

