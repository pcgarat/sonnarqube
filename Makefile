.PHONY: help start stop up down restart status logs clean analyze analyze-all analyze-path list-projects add-project shell

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
		echo "$(RED)Error: El archivo .env no existe.$(NC)"; \
		echo "$(YELLOW)Copia .env-template a .env y configura los valores:$(NC)"; \
		echo "  cp .env-template .env"; \
		exit 1; \
	fi

# Ayuda
help:
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)  SonarQube Docker Compose - Comandos$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(GREEN)Comandos básicos:$(NC)"
	@echo "  $(YELLOW)make start$(NC)          - Inicia los servicios en segundo plano"
	@echo "  $(YELLOW)make stop$(NC)           - Detiene los servicios"
	@echo "  $(YELLOW)make up$(NC)             - Inicia los servicios en primer plano"
	@echo "  $(YELLOW)make down$(NC)            - Detiene y elimina los contenedores"
	@echo "  $(YELLOW)make restart$(NC)         - Reinicia los servicios"
	@echo "  $(YELLOW)make status$(NC)         - Muestra el estado y credenciales"
	@echo "  $(YELLOW)make logs$(NC)            - Muestra los logs de los servicios"
	@echo ""
	@echo "$(GREEN)Análisis de proyectos:$(NC)"
	@echo "  $(YELLOW)make analyze PROJECT=nombre$(NC)     - Analiza un proyecto específico"
	@echo "  $(YELLOW)make analyze-all$(NC)               - Analiza todos los proyectos configurados"
	@echo "  $(YELLOW)make analyze-path PATH=/ruta$(NC)     - Analiza proyecto en ruta específica"
	@echo "  $(YELLOW)make list-projects$(NC)              - Lista proyectos configurados"
	@echo "  $(YELLOW)make add-project$(NC)                - Asistente para añadir nuevo proyecto"
	@echo ""
	@echo "$(GREEN)Utilidades:$(NC)"
	@echo "  $(YELLOW)make clean$(NC)          - Limpia volúmenes (con confirmación)"
	@echo "  $(YELLOW)make shell$(NC)          - Accede al shell de SonarQube"
	@echo "  $(YELLOW)make help$(NC)           - Muestra esta ayuda"
	@echo ""

# Iniciar servicios en segundo plano
start: check-env
	@echo "$(GREEN)Iniciando servicios SonarQube...$(NC)"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d
	@echo "$(GREEN)Servicios iniciados.$(NC)"
	@echo "$(YELLOW)Espera unos segundos para que SonarQube esté listo...$(NC)"
	@echo "$(BLUE)Ejecuta 'make status' para ver el estado.$(NC)"

# Iniciar servicios en primer plano
up: check-env
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up

# Detener servicios
stop:
	@echo "$(YELLOW)Deteniendo servicios...$(NC)"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) stop
	@echo "$(GREEN)Servicios detenidos.$(NC)"

# Detener y eliminar contenedores
down:
	@echo "$(YELLOW)Deteniendo y eliminando contenedores...$(NC)"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down
	@echo "$(GREEN)Contenedores eliminados.$(NC)"
	@echo "$(YELLOW)Nota: Los volúmenes se mantienen. Usa 'make clean' para eliminarlos.$(NC)"

# Reiniciar servicios
restart: stop start

# Mostrar estado y credenciales
status: check-env
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)  Estado de SonarQube$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(GREEN)Estado de contenedores:$(NC)"
	@docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps
	@echo ""
	@echo "$(GREEN)URLs y acceso:$(NC)"
	@echo "  $(YELLOW)SonarQube Web:$(NC)     http://localhost:$$(grep SONARQUBE_PORT $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo '9000')"
	@echo "  $(YELLOW)PostgreSQL:$(NC)        localhost:$$(grep POSTGRES_PORT $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo '5432')"
	@echo ""
	@echo "$(GREEN)Credenciales:$(NC)"
	@echo "  $(YELLOW)SonarQube Admin:$(NC)   $$(grep SONARQUBE_ADMIN_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'admin') / $$(grep SONARQUBE_ADMIN_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'admin')"
	@echo "  $(YELLOW)PostgreSQL User:$(NC)    $$(grep POSTGRES_USER $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonar')"
	@echo "  $(YELLOW)PostgreSQL Password:$(NC) $$(grep POSTGRES_PASSWORD $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonar')"
	@echo ""
	@echo "$(GREEN)Volúmenes:$(NC)"
	@docker volume ls | grep -E "($$(grep COMPOSE_PROJECT_NAME $(ENV_FILE) | cut -d '=' -f2 | tr -d ' ' || echo 'sonarqube')|postgres)" || echo "  No hay volúmenes visibles"
	@echo ""
	@if [ -f $(PROJECTS_CONF) ]; then \
		echo "$(GREEN)Proyectos configurados:$(NC)"; \
		$(SCRIPTS_DIR)/list-projects.sh 2>/dev/null || echo "  $(YELLOW)Ejecuta 'make list-projects' para ver los proyectos$(NC)"; \
	else \
		echo "$(YELLOW)No hay archivo projects.conf. Crea uno para gestionar múltiples proyectos.$(NC)"; \
	fi
	@echo ""

# Ver logs
logs:
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f

# Limpiar volúmenes (con confirmación)
clean:
	@echo "$(RED)⚠️  ADVERTENCIA: Esto eliminará TODOS los datos persistentes.$(NC)"
	@echo "$(YELLOW)Esto incluye:$(NC)"
	@echo "  - Todos los proyectos y análisis en SonarQube"
	@echo "  - Todos los datos de PostgreSQL"
	@echo "  - Todos los plugins y configuraciones"
	@echo ""
	@read -p "$(RED)¿Estás seguro? Escribe 'SI' para confirmar: $(NC)" confirm && [ "$$confirm" = "SI" ] || exit 1
	@echo "$(YELLOW)Eliminando volúmenes...$(NC)"
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down -v
	@echo "$(GREEN)Volúmenes eliminados.$(NC)"

# Acceder al shell de SonarQube
shell:
	docker-compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec sonarqube /bin/bash

# Analizar proyecto específico
analyze: check-env
	@if [ -z "$(PROJECT)" ]; then \
		echo "$(RED)Error: Debes especificar el proyecto con PROJECT=nombre$(NC)"; \
		echo "$(YELLOW)Ejemplo: make analyze PROJECT=mi-proyecto$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f $(SCRIPTS_DIR)/analyze-project.sh ]; then \
		echo "$(RED)Error: El script analyze-project.sh no existe.$(NC)"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/analyze-project.sh --project $(PROJECT)

# Analizar todos los proyectos
analyze-all: check-env
	@if [ ! -f $(SCRIPTS_DIR)/analyze-project.sh ]; then \
		echo "$(RED)Error: El script analyze-project.sh no existe.$(NC)"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/analyze-project.sh --all

# Analizar proyecto por ruta
analyze-path: check-env
	@if [ -z "$(PATH)" ]; then \
		echo "$(RED)Error: Debes especificar la ruta con PATH=/ruta/proyecto$(NC)"; \
		echo "$(YELLOW)Ejemplo: make analyze-path PATH=/home/usuario/mi-proyecto$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f $(SCRIPTS_DIR)/analyze-project.sh ]; then \
		echo "$(RED)Error: El script analyze-project.sh no existe.$(NC)"; \
		exit 1; \
	fi
	@bash $(SCRIPTS_DIR)/analyze-project.sh --path $(PATH)

# Listar proyectos configurados
list-projects:
	@if [ ! -f $(PROJECTS_CONF) ]; then \
		echo "$(YELLOW)No existe el archivo projects.conf$(NC)"; \
		echo "$(BLUE)Crea uno basándote en projects.conf.example$(NC)"; \
		exit 0; \
	fi
	@if [ -f $(SCRIPTS_DIR)/list-projects.sh ]; then \
		bash $(SCRIPTS_DIR)/list-projects.sh; \
	else \
		echo "$(GREEN)Proyectos configurados en $(PROJECTS_CONF):$(NC)"; \
		grep -E "^\[.*\]" $(PROJECTS_CONF) | sed 's/\[\(.*\)\]/\1/' | while read project; do \
			echo "  $(YELLOW)$$project$(NC)"; \
		done; \
	fi

# Asistente para añadir proyecto
add-project:
	@if [ ! -f $(SCRIPTS_DIR)/add-project.sh ]; then \
		echo "$(YELLOW)Asistente no disponible. Edita projects.conf manualmente.$(NC)"; \
		echo "$(BLUE)Ejemplo de entrada:$(NC)"; \
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

