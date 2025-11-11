# SonarQube Docker Setup

Entorno completo de desarrollo local para SonarQube con Docker Compose, diseñado para analizar múltiples proyectos Git locales de forma centralizada y eficiente.

## 🚀 Características

- ✅ SonarQube con PostgreSQL integrado
- ✅ Volúmenes persistentes para datos, logs, plugins y configuración
- ✅ SonarScanner integrado en Docker
- ✅ Gestión centralizada de múltiples proyectos
- ✅ Comandos Make para gestión sencilla
- ✅ Configuración mediante variables de entorno
- ✅ Integración opcional con Git hooks

## 📋 Requisitos Previos

- Docker y Docker Compose instalados
- Make (generalmente preinstalado en Linux/Mac)
- Acceso a internet para descargar imágenes Docker

## 🛠️ Instalación

### 1. Clonar o copiar el proyecto

```bash
cd /ruta/donde/quieres/el/proyecto
# Si es un repositorio Git:
git clone <url-del-repo>
cd sonnarqube
```

### 2. Configurar variables de entorno

```bash
# Copiar el template de configuración
cp .env-template .env

# Editar .env con tus preferencias
nano .env  # o usa tu editor favorito
```

**Variables importantes a configurar:**
- `POSTGRES_PASSWORD`: Contraseña de PostgreSQL (cambiar por defecto)
- `SONARQUBE_ADMIN_PASSWORD`: Se cambia desde la UI después del primer login
- `PROJECTS_ROOT`: Directorio donde están tus proyectos (opcional)

### 3. Iniciar SonarQube

```bash
make start
```

Espera unos segundos para que SonarQube esté completamente iniciado (puede tardar 1-2 minutos la primera vez).

### 4. Verificar que está funcionando

```bash
make status
```

Esto mostrará:
- Estado de los contenedores
- URL de acceso: http://localhost:9000
- Credenciales por defecto: admin / admin

### 5. Acceder a SonarQube

Abre tu navegador y ve a: **http://localhost:9000**

- **Usuario**: admin
- **Contraseña**: admin

**⚠️ IMPORTANTE**: Cambia la contraseña de admin desde la UI después del primer login:
1. Click en tu avatar (arriba derecha)
2. My Account > Security
3. Change password

## 📁 Configuración de Proyectos

### Opción 1: Usar projects.conf (Recomendado para múltiples proyectos)

1. Copia el ejemplo:
```bash
cp projects.conf.example projects.conf
```

2. Edita `projects.conf` y añade tus proyectos:
```ini
[mi-proyecto]
project_key=mi-proyecto
project_name=Mi Proyecto
project_path=/home/usuario/proyectos/mi-proyecto
token=squ_abc123...  # Token de SonarQube
language=java
```

3. Lista tus proyectos configurados:
```bash
make list-projects
```

### Opción 2: Análisis directo por ruta

Puedes analizar cualquier proyecto sin configurarlo previamente:

```bash
make analyze-path PATH=/ruta/al/proyecto --token=squ_tu_token
```

## 🔍 Análisis de Proyectos

### Obtener Token de Autenticación

Antes de analizar proyectos, necesitas un token de SonarQube:

1. Accede a http://localhost:9000
2. Login con admin / (tu contraseña)
3. Click en tu avatar > My Account > Security
4. Genera un nuevo token
5. **Copia el token inmediatamente** (no se puede ver después)

### Analizar un Proyecto Específico

```bash
# Si está en projects.conf
make analyze PROJECT=mi-proyecto

# O con token explícito
make analyze PROJECT=mi-proyecto --token=squ_abc123...
```

### Analizar Todos los Proyectos

```bash
make analyze-all
```

### Analizar Proyecto por Ruta

```bash
make analyze-path PATH=/home/usuario/mi-proyecto --token=squ_abc123...
```

## 📊 Ver Resultados

Después de ejecutar un análisis:

1. Ve a http://localhost:9000
2. En el dashboard verás tu proyecto
3. Click en el proyecto para ver detalles:
   - Issues (bugs, vulnerabilidades, code smells)
   - Cobertura de código
   - Duplicación
   - Métricas de calidad

## 🎮 Comandos Disponibles

### Comandos Básicos

```bash
make start          # Inicia servicios en segundo plano
make stop           # Detiene servicios
make up             # Inicia servicios en primer plano
make down           # Detiene y elimina contenedores
make restart        # Reinicia servicios
make status         # Muestra estado y credenciales
make logs           # Muestra logs de servicios
make help           # Muestra ayuda completa
```

### Comandos de Análisis

```bash
make analyze PROJECT=nombre          # Analiza proyecto específico
make analyze-all                     # Analiza todos los proyectos
make analyze-path PATH=/ruta         # Analiza proyecto en ruta
make list-projects                  # Lista proyectos configurados
```

### Utilidades

```bash
make clean          # Limpia volúmenes (⚠️ elimina todos los datos)
make shell          # Accede al shell de SonarQube
```

## 🔧 Configuración Avanzada

### Ajustar Memoria de SonarQube

Edita `.env` y modifica:
```env
SONAR_WEB_JAVAADDITIONALOPTS=-Xmx2g -Xms512m
```

Ajusta según los recursos de tu máquina:
- Mínimo recomendado: `-Xmx512m -Xms128m`
- Desarrollo: `-Xmx2g -Xms512m`
- Producción: `-Xmx4g -Xms1g`

### Cambiar Puertos

Edita `.env`:
```env
SONARQUBE_PORT=9001
POSTGRES_PORT=5433
```

### Añadir Plugins

1. Descarga el plugin (.jar) de SonarQube Marketplace
2. Cópialo a `volumes/sonarqube/extensions/plugins/`
3. Reinicia: `make restart`

## 🔗 Integración con Git Hooks

Para análisis automático en cada commit:

```bash
# Desde la raíz de tu proyecto Git
cd /ruta/a/tu/proyecto
/path/to/sonnarqube/scripts/git-hook-setup.sh
```

Esto configurará:
- **Pre-commit**: Análisis rápido antes de commit
- **Post-commit**: Análisis completo después de commit (opcional)

## 📚 Estructura del Proyecto

```
sonnarqube/
├── docker-compose.yml          # Configuración Docker Compose
├── .env-template               # Template de variables de entorno
├── .env                        # Variables de entorno (no versionado)
├── Makefile                    # Comandos de gestión
├── projects.conf.example       # Ejemplo de configuración de proyectos
├── projects.conf               # Configuración de proyectos (no versionado)
├── sonar-project.properties.template  # Template para proyectos
├── scripts/
│   ├── analyze-project.sh      # Script de análisis
│   ├── list-projects.sh        # Listar proyectos
│   └── git-hook-setup.sh       # Configurar Git hooks
├── README.md                   # Esta documentación
└── ANALYSIS.md                 # Guía detallada de análisis
```

## 🐛 Troubleshooting

### SonarQube no inicia

1. Verifica que los puertos no estén en uso:
```bash
netstat -tulpn | grep -E '9000|5432'
```

2. Revisa los logs:
```bash
make logs
```

3. Verifica que PostgreSQL esté saludable:
```bash
docker-compose ps
```

### Error de conexión a la base de datos

1. Verifica que PostgreSQL esté corriendo:
```bash
docker-compose ps postgres
```

2. Verifica las credenciales en `.env`

3. Revisa los logs de PostgreSQL:
```bash
docker-compose logs postgres
```

### El análisis falla

1. Verifica que SonarQube esté disponible:
```bash
curl http://localhost:9000/api/system/status
```

2. Verifica que el token sea correcto

3. Verifica que el proyecto exista en SonarQube:
   - Ve a http://localhost:9000
   - Crea el proyecto manualmente si no existe

### Los datos se pierden al reiniciar

Los volúmenes deberían persistir. Si se pierden datos:

1. Verifica que los volúmenes existan:
```bash
docker volume ls | grep sonarqube
```

2. No uses `make clean` a menos que quieras eliminar todo

3. Verifica permisos del directorio de volúmenes

## 🔒 Seguridad

- **NUNCA** subas `.env` o `projects.conf` con tokens al repositorio
- Cambia las contraseñas por defecto
- En producción, usa variables de entorno seguras
- Los tokens de SonarQube son sensibles, trátalos como contraseñas

## 📖 Documentación Adicional

- [ANALYSIS.md](ANALYSIS.md) - Guía detallada de análisis
- [Documentación oficial de SonarQube](https://docs.sonarqube.org/)
- [SonarScanner Documentation](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/)

## 🤝 Contribuir

Si encuentras problemas o tienes sugerencias, por favor:
1. Revisa los issues existentes
2. Crea un nuevo issue con detalles
3. O envía un pull request

## 📝 Licencia

Este proyecto es de código abierto. Úsalo libremente para tus proyectos.

---

**¿Necesitas ayuda?** Revisa `ANALYSIS.md` para más detalles sobre el análisis de código.

