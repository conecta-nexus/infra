# ==============================================================================
# Cloud Run Services (Phase 2 - Enabled when deploy_services = true)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Microservice: Auth (FastAPI + uv)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "auth" {
  count    = var.deploy_services ? 1 : 0
  name     = "conecta-auth"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      image = "${local.artifact_repo_url}/auth:${var.image_tag}"

      ports {
        container_port = 8000
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "PYTHONUNBUFFERED"
        value = "1"
      }
      env {
        name  = "APP_ENV"
        value = "production"
      }
      env {
        name  = "DB_ECHO"
        value = "false"
      }
      env {
        name  = "DATABASE_URL"
        value = "postgresql+asyncpg://${var.db_user}:${local.db_password}@/db_auth?host=/cloudsql/${google_sql_database_instance.postgres.connection_name}"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [
    google_sql_database.databases,
    google_sql_user.db_user,
    google_project_service.services["run.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# 2. Microservice: Profile (Django + DRF + uv)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "profile" {
  count    = var.deploy_services ? 1 : 0
  name     = "conecta-profile"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      image = "${local.artifact_repo_url}/profile:${var.image_tag}"

      ports {
        container_port = 8000
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "PYTHONUNBUFFERED"
        value = "1"
      }
      env {
        name  = "DJANGO_DEBUG"
        value = "False"
      }
      env {
        name  = "DJANGO_ALLOWED_HOSTS"
        value = "*"
      }
      env {
        name  = "DJANGO_SECRET_KEY"
        value = var.django_secret_key
      }
      env {
        name  = "POSTGRES_DB"
        value = "db_profiles"
      }
      env {
        name  = "POSTGRES_USER"
        value = var.db_user
      }
      env {
        name  = "POSTGRES_PASSWORD"
        value = local.db_password
      }
      env {
        name  = "POSTGRES_HOST"
        value = "/cloudsql/${google_sql_database_instance.postgres.connection_name}"
      }
      env {
        name  = "POSTGRES_PORT"
        value = "5432"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [
    google_sql_database.databases,
    google_sql_user.db_user,
    google_project_service.services["run.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# 3. Frontend: Nuxt 4 (Vue 3, Vite, Tailwind CSS)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "frontend" {
  count    = var.deploy_services ? 1 : 0
  name     = "conecta-frontend"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image = "${local.artifact_repo_url}/frontend:${var.image_tag}"

      ports {
        container_port = 3000
      }

      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        name  = "NODE_ENV"
        value = "production"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [
    google_project_service.services["run.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# 4. API Gateway: Nginx Reverse Proxy
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "gateway" {
  count    = var.deploy_services ? 1 : 0
  name     = "conecta-gateway"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image = "${local.artifact_repo_url}/gateway:${var.image_tag}"

      ports {
        container_port = 80
      }

      env {
        name  = "PORT"
        value = "80"
      }
      env {
        name  = "AUTH_URL"
        value = google_cloud_run_v2_service.auth[0].uri
      }
      env {
        name  = "PROFILE_URL"
        value = google_cloud_run_v2_service.profile[0].uri
      }
      env {
        name  = "FRONTEND_URL"
        value = google_cloud_run_v2_service.frontend[0].uri
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }
    }
  }

  depends_on = [
    google_cloud_run_v2_service.auth,
    google_cloud_run_v2_service.profile,
    google_cloud_run_v2_service.frontend,
    google_project_service.services["run.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# Public Access Permissions (roles/run.invoker for allUsers)
# ------------------------------------------------------------------------------

resource "google_cloud_run_v2_service_iam_member" "public_gateway" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.gateway[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "public_frontend" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.frontend[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "public_auth" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.auth[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "public_profile" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.profile[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
