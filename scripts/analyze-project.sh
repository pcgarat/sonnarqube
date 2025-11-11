#!/bin/bash

# ============================================
# Script de Análisis de Proyectos con SonarQube
# ============================================

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
PROJECTS_CONF="$PROJECT_ROOT/projects.conf"
ENV_FILE="$PROJECT_ROOT/.env"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
SONAR_PROPERTIES_TEMPLATE="$PROJECT_ROOT/sonar-project.properties.template"

# Función de ayuda
show_help() {
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "Opciones:"
    echo "  --project KEY     Analiza un proyecto específico por su clave"
    echo "  --path RUTA       Analiza un proyecto en la ruta especificada"
    echo "  --all             Analiza todos los proyectos configurados"
    echo "  --token TOKEN     Token de autenticación (sobrescribe configuración)"
    echo "  --help            Muestra esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --project mi-proyecto"
    echo "  $0 --path /home/usuario/mi-proyecto"
    echo "  $0 --all"
    echo "  $0 --project mi-proyecto --token squ_abc123..."
}

# Función para leer configuración de .env
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

# Función para listar todas las secciones de proyectos
list_project_keys() {
    if [ ! -f "$PROJECTS_CONF" ]; then
        return 1
    fi
    
    grep -E "^\[.*\]" "$PROJECTS_CONF" | sed 's/\[\(.*\)\]/\1/'
}

# Función para crear sonar-project.properties temporal
create_sonar_properties() {
    local project_path=$1
    local project_key=$2
    local project_name=$3
    local token=$4
    local language=$5
    
    local properties_file="$project_path/sonar-project.properties"
    
    # Si ya existe, usarlo
    if [ -f "$properties_file" ]; then
        echo -e "${YELLOW}Usando sonar-project.properties existente${NC}"
        return 0
    fi
    
    # Crear desde template si existe
    if [ -f "$SONAR_PROPERTIES_TEMPLATE" ]; then
        cp "$SONAR_PROPERTIES_TEMPLATE" "$properties_file"
        sed -i "s/\${PROJECT_KEY}/$project_key/g" "$properties_file"
        sed -i "s/\${PROJECT_NAME}/$project_name/g" "$properties_file"
        sed -i "s/\${SONAR_TOKEN}/$token/g" "$properties_file"
        if [ -n "$language" ]; then
            echo "sonar.language=$language" >> "$properties_file"
        fi
        echo -e "${YELLOW}Creado sonar-project.properties temporal${NC}"
    else
        # Crear básico
        cat > "$properties_file" <<EOF
sonar.projectKey=$project_key
sonar.projectName=$project_name
sonar.projectVersion=1.0
sonar.sources=.
sonar.host.url=$(get_env_value SONAR_HOST_URL http://localhost:9000)
sonar.login=$token
sonar.sourceEncoding=UTF-8
EOF
        if [ -n "$language" ]; then
            echo "sonar.language=$language" >> "$properties_file"
        fi
        echo -e "${YELLOW}Creado sonar-project.properties básico${NC}"
    fi
}

# Función para analizar un proyecto
analyze_project() {
    local project_path=$1
    local project_key=$2
    local project_name=$3
    local token=$4
    local language=$5
    
    # Validar que el directorio existe
    if [ ! -d "$project_path" ]; then
        echo -e "${RED}Error: El directorio $project_path no existe${NC}"
        return 1
    fi
    
    # Convertir a ruta absoluta
    project_path=$(cd "$project_path" && pwd)
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Analizando proyecto: $project_name${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Clave:${NC} $project_key"
    echo -e "${GREEN}Ruta:${NC} $project_path"
    echo ""
    
    # Crear sonar-project.properties si no existe
    create_sonar_properties "$project_path" "$project_key" "$project_name" "$token" "$language"
    
    # Verificar que SonarQube está corriendo
    local sonar_url=$(get_env_value SONAR_HOST_URL http://localhost:9000)
    if ! curl -s -f "$sonar_url/api/system/status" > /dev/null 2>&1; then
        echo -e "${RED}Error: SonarQube no está disponible en $sonar_url${NC}"
        echo -e "${YELLOW}Ejecuta 'make start' para iniciar SonarQube${NC}"
        return 1
    fi
    
    # Ejecutar análisis con Docker
    echo -e "${GREEN}Ejecutando análisis...${NC}"
    
    # Obtener configuración de red y URL de SonarQube
    local compose_project=$(get_env_value COMPOSE_PROJECT_NAME sonarqube)
    local network_name="${compose_project}_sonarqube-network"
    local sonar_url=$(get_env_value SONAR_HOST_URL http://localhost:9000)
    
    # Verificar que la red existe, si no usar la red por defecto
    if ! docker network inspect "$network_name" > /dev/null 2>&1; then
        # Intentar encontrar la red del proyecto
        network_name=$(docker network ls --filter "name=${compose_project}" --format "{{.Name}}" | head -1)
        if [ -z "$network_name" ]; then
            echo -e "${YELLOW}Advertencia: No se encontró la red, usando host network${NC}"
            network_name="host"
        fi
    fi
    
    # Usar sonar-scanner como contenedor temporal
    if [ "$network_name" = "host" ]; then
        docker run --rm \
            --network host \
            -v "$project_path:/usr/src" \
            -w /usr/src \
            -e SONAR_HOST_URL="$sonar_url" \
            sonarsource/sonar-scanner-cli:latest
    else
        # Dentro de la red de Docker Compose, usar el nombre del servicio, no el del contenedor
        docker run --rm \
            --network "$network_name" \
            -v "$project_path:/usr/src" \
            -w /usr/src \
            -e SONAR_HOST_URL="http://sonarqube:9000" \
            sonarsource/sonar-scanner-cli:latest
    fi
    
    echo ""
    echo -e "${GREEN}✓ Análisis completado${NC}"
    echo -e "${BLUE}Ver resultados en: $sonar_url/dashboard?id=$project_key${NC}"
    echo ""
}

# Función para analizar proyecto por clave
analyze_by_key() {
    local project_key=$1
    local token=$2
    
    if [ ! -f "$PROJECTS_CONF" ]; then
        echo -e "${RED}Error: No existe el archivo projects.conf${NC}"
        echo -e "${YELLOW}Crea uno basándote en projects.conf.example${NC}"
        return 1
    fi
    
    # Leer configuración del proyecto
    local project_name=$(get_project_config "$project_key" "project_name")
    local project_path=$(get_project_config "$project_key" "project_path")
    local project_token=$(get_project_config "$project_key" "token")
    local language=$(get_project_config "$project_key" "language")
    
    if [ -z "$project_name" ] || [ -z "$project_path" ]; then
        echo -e "${RED}Error: Proyecto '$project_key' no encontrado en projects.conf${NC}"
        echo -e "${YELLOW}Proyectos disponibles:${NC}"
        list_project_keys | sed 's/^/  - /'
        return 1
    fi
    
    # Usar token pasado por parámetro, el de la configuración, o el token del scanner
    if [ -z "$token" ]; then
        token="$project_token"
    fi
    
    # Si aún no hay token, intentar usar el token del scanner desde .env
    if [ -z "$token" ]; then
        token=$(get_env_value SONARQUBE_SCANNER_TOKEN "")
    fi
    
    if [ -z "$token" ]; then
        echo -e "${RED}Error: No se ha especificado token para el proyecto${NC}"
        echo -e "${YELLOW}Opciones:${NC}"
        echo -e "  - Especifica un token con --token"
        echo -e "  - Añádelo a projects.conf"
        echo -e "  - Ejecuta 'make setup-user' para crear un usuario con token automático"
        return 1
    fi
    
    analyze_project "$project_path" "$project_key" "$project_name" "$token" "$language"
}

# Función para analizar proyecto por ruta
analyze_by_path() {
    local project_path=$1
    local token=$2
    
    if [ -z "$project_path" ]; then
        echo -e "${RED}Error: Debes especificar una ruta${NC}"
        return 1
    fi
    
    # Intentar detectar project_key desde sonar-project.properties
    local properties_file="$project_path/sonar-project.properties"
    local project_key=""
    local project_name=""
    
    if [ -f "$properties_file" ]; then
        project_key=$(grep "^sonar.projectKey=" "$properties_file" | cut -d '=' -f2- | tr -d ' ')
        project_name=$(grep "^sonar.projectName=" "$properties_file" | cut -d '=' -f2- | tr -d ' ')
    fi
    
    # Si no se encuentra, usar el nombre del directorio
    if [ -z "$project_key" ]; then
        project_key=$(basename "$project_path")
        project_name="$project_key"
        echo -e "${YELLOW}No se encontró projectKey, usando: $project_key${NC}"
    fi
    
    # Si no hay token, intentar usar el token del scanner desde .env
    if [ -z "$token" ]; then
        token=$(get_env_value SONARQUBE_SCANNER_TOKEN "")
    fi
    
    if [ -z "$token" ]; then
        echo -e "${RED}Error: Debes especificar un token con --token${NC}"
        echo -e "${YELLOW}O ejecuta 'make setup-user' para crear un usuario con token automático${NC}"
        return 1
    fi
    
    analyze_project "$project_path" "$project_key" "$project_name" "$token" ""
}

# Función para analizar todos los proyectos
analyze_all() {
    local token=$1
    
    if [ ! -f "$PROJECTS_CONF" ]; then
        echo -e "${RED}Error: No existe el archivo projects.conf${NC}"
        return 1
    fi
    
    # Si no se proporciona token, intentar usar el del scanner
    if [ -z "$token" ]; then
        token=$(get_env_value SONARQUBE_SCANNER_TOKEN "")
    fi
    
    if [ -z "$token" ]; then
        echo -e "${YELLOW}⚠ Advertencia: No se encontró token.${NC}"
        echo -e "${YELLOW}  Ejecuta 'make setup-user' para crear un usuario con token automático${NC}"
        echo -e "${YELLOW}  O proporciona un token con --token${NC}"
        return 1
    fi
    
    local projects=$(list_project_keys)
    local count=0
    local success=0
    local failed=0
    
    echo -e "${BLUE}Analizando todos los proyectos configurados...${NC}"
    echo ""
    
    while IFS= read -r project_key; do
        if [ -n "$project_key" ]; then
            count=$((count + 1))
            if analyze_by_key "$project_key" "$token"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
            fi
            echo ""
        fi
    done <<< "$projects"
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Resumen:${NC}"
    echo -e "  Total: $count"
    echo -e "  Exitosos: $success"
    echo -e "  Fallidos: $failed"
    echo -e "${BLUE}========================================${NC}"
}

# Parsear argumentos
MODE=""
PROJECT_KEY=""
PROJECT_PATH=""
TOKEN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            MODE="by_key"
            PROJECT_KEY="$2"
            shift 2
            ;;
        --path)
            MODE="by_path"
            PROJECT_PATH="$2"
            shift 2
            ;;
        --all)
            MODE="all"
            shift
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Opción desconocida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validar modo
if [ -z "$MODE" ]; then
    echo -e "${RED}Error: Debes especificar --project, --path o --all${NC}"
    show_help
    exit 1
fi

# Ejecutar según el modo
case $MODE in
    by_key)
        analyze_by_key "$PROJECT_KEY" "$TOKEN"
        ;;
    by_path)
        analyze_by_path "$PROJECT_PATH" "$TOKEN"
        ;;
    all)
        analyze_all "$TOKEN"
        ;;
esac

