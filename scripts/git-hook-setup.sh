#!/bin/bash

# ============================================
# Script de Configuración de Git Hooks para SonarQube
# ============================================
# Este script configura Git hooks para análisis automático con SonarQube
# Ejecuta este script desde la raíz de tu proyecto Git

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || echo "")"

if [ -z "$GIT_DIR" ]; then
    echo -e "${RED}Error: Este no es un directorio Git${NC}"
    echo -e "${YELLOW}Ejecuta este script desde la raíz de un proyecto Git${NC}"
    exit 1
fi

HOOKS_DIR="$GIT_DIR/hooks"
ANALYZE_SCRIPT="$PROJECT_ROOT/scripts/analyze-project.sh"

if [ ! -f "$ANALYZE_SCRIPT" ]; then
    echo -e "${RED}Error: No se encuentra el script analyze-project.sh${NC}"
    exit 1
fi

echo -e "${BLUE}Configurando Git hooks para SonarQube...${NC}"
echo ""

# Leer configuración del proyecto
read -p "Project Key en SonarQube: " PROJECT_KEY
read -p "Token de SonarQube (o Enter para usar el de projects.conf): " TOKEN
read -p "¿Ejecutar análisis en pre-commit? (s/N): " PRE_COMMIT
read -p "¿Ejecutar análisis en post-commit? (s/N): " POST_COMMIT

# Pre-commit hook
if [[ "$PRE_COMMIT" =~ ^[Ss]$ ]]; then
    echo -e "${GREEN}Configurando pre-commit hook...${NC}"
    cat > "$HOOKS_DIR/pre-commit" <<'HOOK_EOF'
#!/bin/bash
# Pre-commit hook para análisis rápido con SonarQube
# Solo analiza archivos modificados

PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"
ANALYZE_SCRIPT="$PROJECT_ROOT/scripts/analyze-project.sh"
PROJECT_KEY="PROJECT_KEY_PLACEHOLDER"
TOKEN="TOKEN_PLACEHOLDER"

echo "Ejecutando análisis rápido de SonarQube..."

# Análisis rápido (solo archivos modificados)
if [ -n "$TOKEN" ]; then
    "$ANALYZE_SCRIPT" --project "$PROJECT_KEY" --token "$TOKEN"
else
    "$ANALYZE_SCRIPT" --project "$PROJECT_KEY"
fi

exit 0
HOOK_EOF
    
    sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$HOOKS_DIR/pre-commit"
    sed -i "s|PROJECT_KEY_PLACEHOLDER|$PROJECT_KEY|g" "$HOOKS_DIR/pre-commit"
    sed -i "s|TOKEN_PLACEHOLDER|$TOKEN|g" "$HOOKS_DIR/pre-commit"
    chmod +x "$HOOKS_DIR/pre-commit"
    echo -e "${GREEN}✓ Pre-commit hook configurado${NC}"
fi

# Post-commit hook
if [[ "$POST_COMMIT" =~ ^[Ss]$ ]]; then
    echo -e "${GREEN}Configurando post-commit hook...${NC}"
    cat > "$HOOKS_DIR/post-commit" <<'HOOK_EOF'
#!/bin/bash
# Post-commit hook para análisis completo con SonarQube

PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"
ANALYZE_SCRIPT="$PROJECT_ROOT/scripts/analyze-project.sh"
PROJECT_KEY="PROJECT_KEY_PLACEHOLDER"
TOKEN="TOKEN_PLACEHOLDER"

echo "Ejecutando análisis completo de SonarQube..."

# Análisis completo en segundo plano
if [ -n "$TOKEN" ]; then
    "$ANALYZE_SCRIPT" --project "$PROJECT_KEY" --token "$TOKEN" &
else
    "$ANALYZE_SCRIPT" --project "$PROJECT_KEY" &
fi

exit 0
HOOK_EOF
    
    sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$HOOKS_DIR/post-commit"
    sed -i "s|PROJECT_KEY_PLACEHOLDER|$PROJECT_KEY|g" "$HOOKS_DIR/post-commit"
    sed -i "s|TOKEN_PLACEHOLDER|$TOKEN|g" "$HOOKS_DIR/post-commit"
    chmod +x "$HOOKS_DIR/post-commit"
    echo -e "${GREEN}✓ Post-commit hook configurado${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Git hooks configurados correctamente${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Nota: Los hooks se ejecutarán automáticamente en cada commit${NC}"
echo -e "${YELLOW}Para desactivarlos, elimina los archivos en .git/hooks/${NC}"

