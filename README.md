# Conecta Nexus — Cloud Infrastructure (GCP + Terraform)

Infraestructura como código (IaC) en Terraform para el despliegue serverless de **Conecta Nexus** sobre **Google Cloud Platform (GCP)**.

---

## 🏛️ Arquitectura del Despliegue en GCP

```
                         [ Internet / Alumnos / Evaluador ]
                                        │
                                        ▼ HTTPS
                     ┌──────────────────────────────────────┐
                     │   API Gateway (Nginx on Cloud Run)   │
                     │         /gateway/health              │
                     └───────┬──────────────────────┬───────┘
           /_auth_verify     │                      │
           /api/v1/auth/*    │                      │ /api/v1/profile*
                             ▼                      ▼
               ┌──────────────────────┐   ┌──────────────────────┐
               │    Auth Service      │   │   Profile Service    │
               │   (FastAPI on Run)   │   │  (Django DRF on Run) │
               └──────────┬───────────┘   └──────────┬───────────┘
                          │                          │
                          │   Unix Socket (/cloudsql)│
                          └───────────┬──────────────┘
                                      │
                                      ▼
                      ┌───────────────────────────────┐
                      │    Cloud SQL (PostgreSQL 16)  │
                      │  - db_auth                    │
                      │  - db_profiles                │
                      │  - db_challenges (pre-creada) │
                      │  - db_applications (pre-creada)
                      │  - db_moderation (pre-creada) │
                      │  - db_notifications(pre-creada)
                      └───────────────────────────────┘
```

### Componentes y Decisiones Técnicas

| Componente | Servicio GCP | Justificación Técnica |
|---|---|---|
| **Contenedores** | **Artifact Registry** | Repositorio Docker privado administrado (`us-central1-docker.pkg.dev/...`) de alta velocidad para imágenes OCI. |
| **API Gateway** | **Cloud Run (Nginx)** | Permite mantener intacto el pipeline de validación criptográfica subrequest (`auth_request /_auth_verify`) e inyección de cabeceras (`X-User-Id`, `X-User-Role`), con HTTPS automático gratuito y costo $0 en reposo. |
| **Frontend** | **Cloud Run (Nuxt 4)** | Servidor Node SSR optimizado, escalable y servido a través del Gateway o directamente. |
| **Microservicios (auth, profile)** | **Cloud Run** | Ejecución serverless de FastAPI y Django DRF con autoescalado (0 a N instancias) y conexión nativa a Cloud SQL por socket Unix seguro. |
| **Base de Datos** | **Cloud SQL PostgreSQL 16** | Instancia compartida costo-eficiente que aprovisiona automáticamente bases de datos dedicadas para cada microservicio (`db_auth`, `db_profiles`, etc.). |
| **Permisos e Identidad** | **Service Account & IAM** | Cuenta de servicio (`sa-conecta-runner`) con roles mínimos necesarios (`roles/cloudsql.client`, `roles/logging.logWriter`). |

---

## 🚀 Estrategia de Despliegue Parcial (Partial Deployment)

Para evitar el bloqueo de Terraform al intentar crear servicios en Cloud Run antes de que existan las imágenes en Artifact Registry, la infraestructura se divide en **3 fases**:

1. **Fase 1 (Cimientos de Infraestructura)**: Habilita APIs de GCP, crea el repositorio en Artifact Registry, provisiona Cloud SQL (con todas las bases de datos) y configura las Service Accounts e IAM.
2. **Fase 2 (Construcción y Push de Imágenes)**: Ejecuta Google Cloud Build para empaquetar y subir los contenedores (`auth`, `profile`, `frontend`, `gateway`) hacia Artifact Registry.
3. **Fase 3 (Despliegue de Servicios Cloud Run)**: Activa la bandera `deploy_services = true` en Terraform, desplegando los microservicios y el API Gateway enlazado a las URLs generadas.

---

## 🛠️ Requisitos Previos

1. [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install) instalado y autenticado:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
2. [Terraform](https://developer.hashicorp.com/terraform/install) (versión `>= 1.5.0`).
3. Un proyecto de Google Cloud con facturación activa.

---

## ⚡ Despliegue Rápido Automatizado

1. **Configurar variables**:
   Copia el archivo de ejemplo y edita tu `project_id`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edita `terraform.tfvars`:
   ```hcl
   project_id = "tu-proyecto-gcp"
   region     = "us-central1"
   ```

2. **Ejecutar el script de despliegue**:
   ```bash
   ./scripts/deploy.sh
   ```
   *El script ejecutará automáticamente la Fase 1, la compilación en Cloud Build (Fase 2) y el despliegue en Cloud Run (Fase 3).*

---

## 📖 Despliegue Manual Paso a Paso

Si prefieres ejecutar cada fase de manera manual:

### Paso 1: Provisionar Infraestructura Base (Fase 1)
```bash
terraform init
terraform apply -var="deploy_services=false"
```

### Paso 2: Compilar y Subir Contenedores con Cloud Build (Fase 2)
```bash
./scripts/build_and_push.sh
```
*(Opcionalmente pasando argumentos: `./scripts/build_and_push.sh <PROJECT_ID> <REGION> <REPO_ID> <TAG>`)*

### Paso 3: Desplegar Microservicios en Cloud Run (Fase 3)
```bash
terraform apply -var="deploy_services=true"
```

Al finalizar, Terraform mostrará las URLs públicas de acceso:
- `gateway_url`: Punto de entrada unificado y enrutador principal.
- `frontend_url`: Interfaz gráfica web de Conecta Nexus.
- `auth_service_url`: Microservicio de autenticación.
- `profile_service_url`: Microservicio de perfiles.

---

## 🧪 Pruebas de Verificación Post-Despliegue

### 1. Diagnóstico del Gateway
```bash
curl -i https://<GATEWAY_URL>/gateway/health
```
Respuesta esperada: `{"status":"healthy","service":"gateway"}`

### 2. Diagnóstico de Microservicio Auth
```bash
curl -i https://<GATEWAY_URL>/services/auth/
```

### 3. Registro y Login a través del Gateway
```bash
# Registro
curl -X POST https://<GATEWAY_URL>/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "estudiante@ufps.edu.co",
    "password": "Password123*",
    "role": "STUDENT"
  }'

# Login
curl -X POST https://<GATEWAY_URL>/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "estudiante@ufps.edu.co",
    "password": "Password123*"
  }'
```

---

## 🧹 Limpieza y Destrucción

Para evitar consumos de créditos una vez finalizada la presentación o clase:
```bash
terraform destroy
```
