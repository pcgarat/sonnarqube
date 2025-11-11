.PHONY: help start stop up down restart status logs clean analyze analyze-all analyze-path list-projects add-project remove-project setup-user shell

# Variables
COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env
PROJECTS_CONF := projects.conf
SCRIPTS_DIR := scripts

# Colores para output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Verificar que existe .env
check-env:
	@if [ ! -f $(ENV_FILE) ]; then \
		printf "$(RED)Error: El archivo .env no existe.$(NC)\n"; \
		printf "$(YELLOW)Copia .env-template a .env y configura los valores:$(NC)\n"; \
		echo "  cp .env-template .env"; \
		exit 1; \
	fi

# Ayuda
help:
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)  SonarQube Docker Compose - Comandos$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""
	@printf "$(GREEN)Comandos básicos:$(NC)\n"
	@printf "  $(YELLOW)make start$(NC)          - Inicia los servicios en segundo plano\n"
	@printf "  $(YELLOW)make stop$(NC)           - Detiene los servicios\n"
	@printf "  $(YELLOW)make up$(NC)             - Inicia los servicios en primer plano\n"
	@printf "  $(YELLOW)make down$(NC)            - Detiene y elimina los contenedores\n"
	@printf "  $(YELLOW)make restart$(NC)         - Reinicia los servicios\n"
	@printf "  $(YELLOW)make status$(NC)         - Muestra el estado y credenciales\n"
	@printf "  $(YELLOW)make logs$(NC)            - Muestra los logs de los servicios\n"
	@echo ""
	@printf "$(GREEN)Análisis de proyectos:$(NC)\n"
	@printf "  $(YELLOW)make analyze PROJECT=nombre$(NC)     - Analiza un proyecto específico\n"
	@printf "  $(YELLOW)make analyze-all$(NC)               - Analiza todos los proyectos configurados\n"
	@printf "  $(YELLOW)make analyze-path PATH=/ruta$(NC)     - Analiza proyecto en ruta específica\n"
	@printf "  $(YELLOW)make list-projects$(NC)              - Lista proyectos configurados\n"
	@printf "  $(YELLOW)make add-project$(NC)                - Asistente para añadir nuevo proyecto\n"
	@printf "  $(YELLOW)make remove-project PROJECT=nombre$(NC) - Elimina un proyecto de la configuración\n"
	@echo ""
	@printf "$(GREEN)Utilidades:$(NC)\n"
	@printf "  $(YELLOW)make setup-user$(NC)     - Configura usuario con permisos completos\n"
	@printf "  $(YELLOW)make clean$(NC)          - Limpia volúmenes (con confirmación)\n"
	@printf "  $(YELLOW)make shell$(NC)          - Accede al shell de SonarQube\n"
	@printf "  $(YELLOW)make help$(NC)           - Muestra esta ayuda\n"
	@echo ""

# Iniciar servicios en segundo plano
start: check-env
	@printf "$(GREEN)Iniciando servicios SonarQube en segundo plano...$(NC)\n"
	@docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d &
	@sleep 0.1
	@printf "$(GREEN)✓ Comando enviado. Los servicios se están iniciando en segundo plano.$(NC)\n"
	@printf "$(YELLOW)Los contenedores están iniciándose. Puede tardar unos segundos.$(NC)\n"
	@echo ""
	@printf "$(GREEN)Credenciales:$(NC)\n"
	@printf "  $(YELLOW)SonarQube Admin:$(NC)   $$(grep SONARQUBE_ADMIN_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'admin') / $$(grep SONARQUBE_ADMIN_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'admin')\n"
	@if grep -q "^SONARQUBE_USER=" $(ENV_FILE) 2>/dev/null; then \
		printf "  $(YELLOW)SonarQube Scanner:$(NC) $$(grep SONARQUBE_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ') / $$(grep SONARQUBE_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ')\n"; \
		if grep -q "^SONARQUBE_SCANNER_TOKEN=" $(ENV_FILE) 2>/dev/null; then \
			token=$$(grep SONARQUBE_SCANNER_TOKEN $(ENV_FILE) | cut -d '=' -f2 | tr -d ' '); \
			printf "  $(YELLOW)Scanner Token:$(NC)     $${token:0:20}...\n"; \
		fi; \
	else \
		printf "  $(YELLOW)SonarQube Scanner:$(NC) (no configurado - ejecuta 'make setup-user')\n"; \
	fi
	@echo ""
	@printf "$(BLUE)Ejecuta 'make status' para ver el estado o 'make logs' para ver los logs.$(NC)\n"
	@if ! grep -q "^SONARQUBE_USER=" $(ENV_FILE) 2>/dev/null; then \
		printf "$(YELLOW)Ejecuta 'make setup-user' después de que SonarQube esté listo para configurar el usuario con permisos.$(NC)\n"; \
	fi

# Configurar usuario de SonarQube con permisos completos
setup-user: check-env
	@if [ ! -f $(SCRIPTS_DIR)/setup-sonarqube-user.sh ]; then \
		printf "$(RED)Error: El script setup-sonarqube-user.sh no existe.$(NC)\n"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/setup-sonarqube-user.sh

# Iniciar servicios en primer plano
up: check-env
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up

# Detener servicios
stop:
	@printf "$(YELLOW)Deteniendo servicios...$(NC)\n"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) stop
	@printf "$(GREEN)Servicios detenidos.$(NC)\n"

# Detener y eliminar contenedores
down:
	@printf "$(YELLOW)Deteniendo y eliminando contenedores...$(NC)\n"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@printf "$(GREEN)Contenedores eliminados.$(NC)\n"
	@printf "$(YELLOW)Nota: Los volúmenes se mantienen. Usa 'make clean' para eliminarlos.$(NC)\n"

# Reiniciar servicios
restart: stop start

# Mostrar estado y credenciales
status: check-env
	@printf "$(BLUE)========================================$(NC)\n"
	@printf "$(BLUE)  Estado de SonarQube$(NC)\n"
	@printf "$(BLUE)========================================$(NC)\n"
	@echo ""
	@printf "$(GREEN)Estado de contenedores:$(NC)\n"
	@docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps
	@echo ""
	@printf "$(GREEN)URLs y acceso:$(NC)\n"
	@printf "  $(YELLOW)SonarQube Web:$(NC)     http://localhost:$$(grep SONARQUBE_PORT $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo '9000')\n"
	@printf "  $(YELLOW)PostgreSQL:$(NC)        localhost:$$(grep POSTGRES_PORT $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo '5432')\n"
	@echo ""
	@printf "$(GREEN)Credenciales:$(NC)\n"
	@printf "  $(YELLOW)SonarQube Admin:$(NC)   $$(grep SONARQUBE_ADMIN_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'admin') / $$(grep SONARQUBE_ADMIN_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'admin')\n"
	@if grep -q "^SONARQUBE_USER=" $(ENV_FILE) 2>/dev/null; then \
		printf "  $(YELLOW)SonarQube Scanner:$(NC) $$(grep SONARQUBE_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ') / $$(grep SONARQUBE_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ')\n"; \
		if grep -q "^SONARQUBE_SCANNER_TOKEN=" $(ENV_FILE) 2>/dev/null; then \
			token=$$(grep SONARQUBE_SCANNER_TOKEN $(ENV_FILE) | cut -d '=' -f2 | tr -d ' '); \
			printf "  $(YELLOW)Scanner Token:$(NC)     $${token:0:20}...\n"; \
		fi; \
	fi
	@printf "  $(YELLOW)PostgreSQL User:$(NC)    $$(grep POSTGRES_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonar')\n"
	@printf "  $(YELLOW)PostgreSQL Password:$(NC) $$(grep POSTGRES_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonar')\n"
	@echo ""
	@printf "$(GREEN)Volúmenes:$(NC)\n"
	@docker volume ls | grep -E "($$(grep COMPOSE_PROJECT_NAME $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonarqube')|postgres)" || echo "  No hay volúmenes visibles"
	@echo ""
	@if [ -f $(PROJECTS_CONF) ]; then \
		printf "$(GREEN)Proyectos configurados:$(NC)\n"; \
		$(SCRIPTS_DIR)/list-projects.sh 2>/dev/null || printf "  $(YELLOW)Ejecuta 'make list-projects' para ver los proyectos$(NC)\n"; \
	else \
		printf "$(YELLOW)No hay archivo projects.conf. Crea uno para gestionar múltiples proyectos.$(NC)\n"; \
	fi
	@echo ""

# Ver logs
logs:
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f

# Limpiar volúmenes (con confirmación)
clean:
	@printf "$(RED)⚠️  ADVERTENCIA: Esto eliminará TODOS los datos persistentes.$(NC)\n"
	@printf "$(YELLOW)Esto incluye:$(NC)\n"
	@echo "  - Todos los proyectos y análisis en SonarQube"
	@echo "  - Todos los datos de PostgreSQL"
	@echo "  - Todos los plugins y configuraciones"
	@echo ""
	@printf "$(RED)¿Estás seguro? Escribe 'si' para confirmar: $(NC)"; \
	read confirm && \
		case "$$(echo $$confirm | tr '[:upper:]' '[:lower:]')" in \
			si|sí|yes|y) \
				printf "$(YELLOW)Deteniendo contenedores...$(NC)\n"; \
				docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down; \
				printf "$(YELLOW)Eliminando volúmenes...$(NC)\n"; \
				docker volume ls --filter "name=$$(grep COMPOSE_PROJECT_NAME $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonarqube')" -q | xargs -r docker volume rm -f 2>/dev/null || true; \
				docker volume ls --filter "name=postgres" -q | xargs -r docker volume rm -f 2>/dev/null || true; \
				printf "$(GREEN)✓ Volúmenes eliminados.$(NC)\n"; \
				printf "$(BLUE)Nota: projects.conf no se elimina. Usa 'make remove-project' para eliminar proyectos individuales.$(NC)\n"; \
				;; \
			*) \
				printf "$(YELLOW)Operación cancelada.$(NC)\n"; \
				exit 1; \
				;; \
		esac

# Acceder al shell de SonarQube
shell:
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec sonarqube /bin/bash

# Analizar proyecto específico
analyze: check-env
	@if [ -z "$(PROJECT)" ]; then \
		printf "$(RED)Error: Debes especificar el proyecto con PROJECT=nombre$(NC)\n"; \
		printf "$(YELLOW)Ejemplo: make analyze PROJECT=mi-proyecto$(NC)\n"; \
		exit 1; \
	fi
	@if [ ! -f $(SCRIPTS_DIR)/analyze-project.sh ]; then \
		printf "$(RED)Error: El script analyze-project.sh no existe.$(NC)\n"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/analyze-project.sh --project $(PROJECT)

# Analizar todos los proyectos
analyze-all: check-env
	@if [ ! -f $(SCRIPTS_DIR)/analyze-project.sh ]; then \
		printf "$(RED)Error: El script analyze-project.sh no existe.$(NC)\n"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/analyze-project.sh --all

# Analizar proyecto por ruta
analyze-path: check-env
	@if [ -z "$(PATH)" ]; then \
		printf "$(RED)Error: Debes especificar la ruta con PATH=/ruta/proyecto$(NC)\n"; \
		printf "$(YELLOW)Ejemplo: make analyze-path PATH=/home/usuario/mi-proyecto$(NC)\n"; \
		exit 1; \
	fi
	@if [ ! -f $(SCRIPTS_DIR)/analyze-project.sh ]; then \
		printf "$(RED)Error: El script analyze-project.sh no existe.$(NC)\n"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/analyze-project.sh --path $(PATH)

# Listar proyectos configurados
list-projects:
	@if [ ! -f $(PROJECTS_CONF) ]; then \
		printf "$(YELLOW)No existe el archivo projects.conf$(NC)\n"; \
		printf "$(BLUE)Crea uno basándote en projects.conf.example$(NC)\n"; \
		exit 0; \
	fi
	@if [ -f $(SCRIPTS_DIR)/list-projects.sh ]; then \
		bash $(SCRIPTS_DIR)/list-projects.sh; \
	else \
		printf "$(GREEN)Proyectos configurados en $(PROJECTS_CONF):$(NC)\n"; \
		grep -E "^\[.*\]" $(PROJECTS_CONF) | sed 's/\[\(.*\)\]/\1/' | while read project; do \
			printf "  $(YELLOW)$$project$(NC)\n"; \
		done; \
	fi

# Asistente para añadir proyecto
add-project:
	@if [ ! -f $(SCRIPTS_DIR)/add-project.sh ]; then \
		printf "$(YELLOW)Asistente no disponible. Edita projects.conf manualmente.$(NC)\n"; \
		printf "$(BLUE)Ejemplo de entrada:$(NC)\n"; \
		echo ""; \
		echo "[mi-proyecto]"; \
		echo "project_key=mi-proyecto"; \
		echo "project_name=Mi Proyecto"; \
		echo "project_path=/ruta/absoluta/al/proyecto"; \
		echo "token=tu_token_aqui"; \
		echo "language=java"; \
		exit 0; \
	fi
	@bash $(SCRIPTS_DIR)/add-project.sh

# Eliminar proyecto
remove-project:
	@if [ -z "$(PROJECT)" ]; then \
		printf "$(RED)Error: Debes especificar el proyecto con PROJECT=nombre$(NC)\n"; \
		printf "$(YELLOW)Ejemplo: make remove-project PROJECT=mi-proyecto$(NC)\n"; \
		printf "$(YELLOW)Para eliminar también de SonarQube: make remove-project PROJECT=mi-proyecto DELETE_FROM_SONAR=true$(NC)\n"; \
		exit 1; \
	fi
	@if [ ! -f $(SCRIPTS_DIR)/remove-project.sh ]; then \
		printf "$(RED)Error: El script remove-project.sh no existe.$(NC)\n"; \
		exit 1; \
	fi
	@if [ "$(DELETE_FROM_SONAR)" = "true" ]; then \
		bash $(SCRIPTS_DIR)/remove-project.sh $(PROJECT) --delete-from-sonar; \
	else \
		bash $(SCRIPTS_DIR)/remove-project.sh $(PROJECT); \
	fi

