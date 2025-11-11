# Guía de Análisis con SonarQube

Esta guía explica en detalle cómo usar SonarQube para analizar tus proyectos y cómo interpretar los resultados.

## 📖 Índice

1. [Cómo Funciona SonarQube](#cómo-funciona-sonarqube)
2. [Flujo de Trabajo Recomendado](#flujo-de-trabajo-recomendado)
3. [Configuración de Proyectos](#configuración-de-proyectos)
4. [Ejecución de Análisis](#ejecución-de-análisis)
5. [Interpretación de Resultados](#interpretación-de-resultados)
6. [Integración con Git](#integración-con-git)
7. [Automatización con CI/CD](#automatización-con-cicd)
8. [Mejores Prácticas](#mejores-prácticas)

## 🔄 Cómo Funciona SonarQube

### Proceso de Análisis

SonarQube **NO sincroniza automáticamente** desde la aplicación web. El flujo es:

1. **Ejecutas SonarScanner** desde la raíz de tu proyecto
2. **SonarScanner lee** `sonar-project.properties` o parámetros CLI
3. **El análisis se envía** al servidor SonarQube
4. **Los resultados se muestran** en la UI web

### Componentes

- **SonarQube Server**: Servidor que almacena y muestra resultados
- **SonarScanner**: Herramienta que analiza el código y envía resultados
- **PostgreSQL**: Base de datos donde se almacenan los datos

### Para Múltiples Proyectos

- Cada proyecto necesita un `projectKey` único en SonarQube
- Cada proyecto puede tener su propio `sonar-project.properties`
- O usar `projects.conf` para gestión centralizada

## 🚀 Flujo de Trabajo Recomendado

### Primera Vez

1. **Iniciar SonarQube**
   ```bash
   make start
   make status  # Verificar que esté listo
   ```

2. **Acceder a la UI**
   - URL: http://localhost:9000
   - Credenciales: admin / admin
   - **Cambiar contraseña** inmediatamente

3. **Crear Proyecto en SonarQube**
   - Click en "Create Project"
   - Selecciona "Manually"
   - Project Key: `mi-proyecto` (debe ser único)
   - Display Name: `Mi Proyecto`

4. **Generar Token**
   - My Account > Security > Generate Token
   - Nombre: `mi-proyecto-token`
   - Tipo: Project Analysis Token
   - **Copia el token** (no se puede ver después)

5. **Configurar en projects.conf**
   ```ini
   [mi-proyecto]
   project_key=mi-proyecto
   project_name=Mi Proyecto
   project_path=/home/usuario/proyectos/mi-proyecto
   token=squ_abc123...
   language=java
   ```

6. **Ejecutar Primer Análisis**
   ```bash
   make analyze PROJECT=mi-proyecto
   ```

### Uso Diario

```bash
# Analizar proyecto específico
make analyze PROJECT=mi-proyecto

# Ver resultados en http://localhost:9000
# Corregir issues encontrados
# Re-analizar para ver mejoras
```

## ⚙️ Configuración de Proyectos

### Opción 1: projects.conf (Recomendado)

**Ventajas:**
- Gestión centralizada
- Fácil añadir/quitar proyectos
- Tokens almacenados (opcional)

**Configuración:**
```ini
[proyecto-1]
project_key=proyecto-1
project_name=Proyecto 1
project_path=/home/usuario/proyectos/proyecto-1
token=squ_abc123...
language=java

[proyecto-2]
project_key=proyecto-2
project_name=Proyecto 2
project_path=/home/usuario/proyectos/proyecto-2
token=squ_xyz789...
language=python
```

### Opción 2: sonar-project.properties por Proyecto

**Ventajas:**
- Configuración específica por proyecto
- Puede estar versionado en Git
- Más control granular

**Ubicación:** Raíz del proyecto

**Contenido:**
```properties
sonar.projectKey=mi-proyecto
sonar.projectName=Mi Proyecto
sonar.projectVersion=1.0
sonar.sources=.
sonar.host.url=http://localhost:9000
sonar.login=squ_abc123...
sonar.sourceEncoding=UTF-8
```

**⚠️ Importante:** No subas el token al repositorio. Usa variables de entorno o pásalo por CLI.

### Opción 3: Parámetros CLI

**Ventajas:**
- Sin archivos de configuración
- Útil para análisis puntuales

**Ejemplo:**
```bash
docker run --rm \
  -v /ruta/proyecto:/usr/src \
  -w /usr/src \
  -e SONAR_HOST_URL=http://localhost:9000 \
  sonarsource/sonar-scanner-cli:latest \
  -Dsonar.projectKey=mi-proyecto \
  -Dsonar.login=squ_abc123...
```

## 🔍 Ejecución de Análisis

### Análisis de Proyecto Específico

```bash
# Desde projects.conf
make analyze PROJECT=mi-proyecto

# Con token explícito
make analyze PROJECT=mi-proyecto --token=squ_abc123...
```

### Análisis de Todos los Proyectos

```bash
make analyze-all
```

Útil para:
- Análisis periódico de todos los proyectos
- Verificar estado general
- CI/CD pipelines

### Análisis por Ruta

```bash
make analyze-path PATH=/home/usuario/nuevo-proyecto --token=squ_abc123...
```

Útil para:
- Proyectos nuevos sin configurar
- Análisis puntuales
- Testing

### Verificación Pre-Análisis

Antes de analizar, verifica:

1. **SonarQube está corriendo**
   ```bash
   make status
   curl http://localhost:9000/api/system/status
   ```

2. **El proyecto existe en SonarQube**
   - Ve a http://localhost:9000
   - Verifica que el proyecto esté creado

3. **El token es válido**
   - Genera uno nuevo si es necesario

4. **El código está actualizado**
   - Haz commit de tus cambios
   - O analiza desde una rama específica

## 📊 Interpretación de Resultados

### Dashboard Principal

Al acceder a un proyecto en SonarQube verás:

#### Métricas Principales

- **Reliability**: Bugs y errores
- **Security**: Vulnerabilidades de seguridad
- **Maintainability**: Code smells (deuda técnica)
- **Coverage**: Cobertura de tests
- **Duplications**: Código duplicado

#### Quality Gate

Indica si el proyecto pasa los criterios de calidad:
- ✅ **Passed**: Cumple los estándares
- ❌ **Failed**: No cumple (revisar issues)

### Tipos de Issues

#### 🐛 Bugs
Errores que pueden causar comportamiento incorrecto:
- **Critical**: Puede causar fallos graves
- **Major**: Puede causar fallos en ciertas situaciones
- **Minor**: Menos probable que cause problemas

#### 🔒 Vulnerabilities
Problemas de seguridad:
- **Critical**: Riesgo de seguridad alto
- **High**: Riesgo significativo
- **Medium**: Riesgo moderado

#### 💡 Code Smells
Problemas de mantenibilidad:
- **Major**: Impacta significativamente la mantenibilidad
- **Minor**: Impacto menor en mantenibilidad

### Cobertura de Código

- **Lines**: Porcentaje de líneas ejecutadas por tests
- **Branches**: Porcentaje de ramas cubiertas
- **Functions**: Porcentaje de funciones testeadas

**Objetivos recomendados:**
- Mínimo: 60% de cobertura
- Bueno: 80% de cobertura
- Excelente: 90%+ de cobertura

### Duplicación

- **Duplicated Lines**: Líneas duplicadas
- **Duplicated Blocks**: Bloques duplicados
- **Duplicated Files**: Archivos duplicados

**Objetivo:** < 3% de duplicación

### Deuda Técnica

Tiempo estimado para corregir todos los code smells:
- Se calcula automáticamente
- Objetivo: Mantener bajo y estable

## 🔗 Integración con Git

### Git Hooks Automáticos

Configurar análisis automático:

```bash
cd /ruta/a/tu/proyecto
/path/to/sonnarqube/scripts/git-hook-setup.sh
```

**Pre-commit Hook:**
- Análisis rápido antes de commit
- Puede bloquear commits si hay issues críticos

**Post-commit Hook:**
- Análisis completo después de commit
- Se ejecuta en segundo plano
- No bloquea el commit

### Análisis por Rama

Para analizar ramas específicas:

1. Cambia a la rama:
   ```bash
   git checkout feature/nueva-funcionalidad
   ```

2. Analiza:
   ```bash
   make analyze PROJECT=mi-proyecto
   ```

3. SonarQube mostrará los resultados de esa rama

### Análisis de Pull Requests

SonarQube puede analizar PRs automáticamente si está configurado en CI/CD.

## 🤖 Automatización con CI/CD

### GitHub Actions

Ejemplo básico:

```yaml
name: SonarQube Analysis

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  sonarqube:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: SonarQube Scan
        uses: sonarsource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: http://tu-sonarqube:9000
```

### GitLab CI

```yaml
sonarqube:
  image: sonarsource/sonar-scanner-cli:latest
  script:
    - sonar-scanner
      -Dsonar.host.url=http://tu-sonarqube:9000
      -Dsonar.login=$SONAR_TOKEN
  only:
    - main
    - develop
```

### Jenkins

```groovy
stage('SonarQube Analysis') {
    steps {
        withSonarQubeEnv('SonarQube') {
            sh 'sonar-scanner'
        }
    }
}
```

## 💡 Mejores Prácticas

### 1. Análisis Regular

- **Desarrollo activo**: Análisis diario o en cada commit
- **Proyectos estables**: Análisis semanal
- **Antes de releases**: Análisis completo obligatorio

### 2. Corregir Issues Gradualmente

- **Priorizar**: Critical > High > Medium > Low
- **Enfoque**: Corregir los más importantes primero
- **Objetivo**: Mantener Quality Gate en verde

### 3. Configurar Quality Gates

Define criterios mínimos:
- Máximo X bugs críticos
- Máximo Y vulnerabilidades
- Mínimo Z% de cobertura
- Máximo W% de duplicación

### 4. Revisar Tendencias

- **Dashboard**: Ver evolución del proyecto
- **Métricas**: Identificar tendencias negativas
- **Acción**: Actuar antes de que empeore

### 5. Integrar con Desarrollo

- **IDE Plugins**: SonarLint para análisis en tiempo real
- **Git Hooks**: Análisis automático
- **CI/CD**: Análisis en cada build

### 6. Mantener Configuración Actualizada

- **Plugins**: Actualizar regularmente
- **Reglas**: Ajustar según necesidades del proyecto
- **Exclusiones**: Configurar archivos/carpetas a ignorar

## 🎯 Objetivos de Calidad

### Niveles Recomendados

**Básico:**
- 0 bugs críticos
- 0 vulnerabilidades críticas
- 60% cobertura mínima

**Bueno:**
- 0 bugs críticos/mayores
- 0 vulnerabilidades críticas/altas
- 80% cobertura mínima
- < 3% duplicación

**Excelente:**
- Quality Gate siempre en verde
- 90%+ cobertura
- < 1% duplicación
- Deuda técnica < 5% del tiempo de desarrollo

## 🔧 Configuración Avanzada

### Exclusiones

Excluir archivos/carpetas del análisis:

```properties
# Excluir directorios
sonar.exclusions=**/test/**,**/target/**,**/node_modules/**

# Excluir tipos de archivo
sonar.exclusions=**/*.min.js,**/*.bundle.js

# Excluir tests
sonar.test.exclusions=**/src/test/**
```

### Inclusiones

Incluir solo archivos específicos:

```properties
sonar.inclusions=**/*.java,**/*.js
```

### Reglas Personalizadas

1. Ve a Quality Profiles en SonarQube
2. Crea un perfil personalizado
3. Activa/desactiva reglas según necesidades
4. Asigna el perfil a tu proyecto

## 📚 Recursos Adicionales

- [Documentación oficial de SonarQube](https://docs.sonarqube.org/)
- [SonarScanner Documentation](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/)
- [Quality Gates](https://docs.sonarqube.org/latest/user-guide/quality-gates/)
- [SonarLint (IDE Plugin)](https://www.sonarlint.org/)

---

**¿Preguntas?** Revisa el [README.md](README.md) o los logs con `make logs`.

