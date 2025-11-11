#!/bin/bash

# Script para listar proyectos configurados

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_CONF="$PROJECT_ROOT/projects.conf"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f "$PROJECTS_CONF" ]; then
    echo -e "${YELLOW}No existe el archivo projects.conf${NC}"
    exit 0
fi

echo -e "${BLUE}Proyectos configurados:${NC}"
echo ""

# Leer proyectos del archivo
while IFS= read -r line; do
    if [[ "$line" =~ ^\[.*\]$ ]]; then
        project_key=$(echo "$line" | sed 's/\[\(.*\)\]/\1/')
        project_name=$(grep -A 10 "^\[$project_key\]" "$PROJECTS_CONF" | grep "^project_name=" | cut -d '=' -f2- | tr -d ' ')
        project_path=$(grep -A 10 "^\[$project_key\]" "$PROJECTS_CONF" | grep "^project_path=" | cut -d '=' -f2- | tr -d ' ')
        
        echo -e "${GREEN}  [$project_key]${NC}"
        if [ -n "$project_name" ]; then
            echo -e "    Nombre: $project_name"
        fi
        if [ -n "$project_path" ]; then
            echo -e "    Ruta: $project_path"
            if [ -d "$project_path" ]; then
                echo -e "    ${GREEN}✓ Directorio existe${NC}"
            else
                echo -e "    ${YELLOW}⚠ Directorio no existe${NC}"
            fi
        fi
        echo ""
    fi
done < "$PROJECTS_CONF"

