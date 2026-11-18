# ==============================================================================
# Cloud Run Services (Phase 2 - Enabled when deploy_services = true)
# ==============================================================================

# ------------------------------------------------------------------------------
# RSA Key Pair for RS256 JWT Authentication (ADR-002)
# ------------------------------------------------------------------------------
resource "tls_private_key" "jwt_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

locals {
  jwt_private_key = var.jwt_private_key != "" ? var.jwt_private_key : tls_private_key.jwt_key.private_key_pem
  jwt_public_key  = var.jwt_public_key != "" ? var.jwt_public_key : tls_private_key.jwt_key.public_key_pem
}

# ------------------------------------------------------------------------------
# 1. Microservice: Auth (FastAPI + uv)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "auth" {
  count               = var.deploy_services ? 1 : 0
  name                = "conecta-auth"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

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
      env {
        name  = "JWT_PRIVATE_KEY"
        value = local.jwt_private_key
      }
      env {
        name  = "JWT_PUBLIC_KEY"
        value = local.jwt_public_key
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
  count               = var.deploy_services ? 1 : 0
  name                = "conecta-profile"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

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
      env {
        name  = "JWT_PUBLIC_KEY"
        value = local.jwt_public_key
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
  count               = var.deploy_services ? 1 : 0
  name                = "conecta-frontend"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

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
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "NUXT_TELEMETRY_DISABLED"
        value = "1"
      }
      env {
        name  = "NUXT_PUBLIC_API_BASE"
        value = "/api/v1"
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
  count               = var.deploy_services ? 1 : 0
  name                = "conecta-gateway"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image = "${local.artifact_repo_url}/gateway:${var.image_tag}"

      ports {
        container_port = 80
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
        name  = "CHALLENGE_URL"
        value = google_cloud_run_v2_service.challenge[0].uri
      }
      env {
        name  = "APPLICATION_URL"
        value = google_cloud_run_v2_service.application[0].uri
      }
      env {
        name  = "FRONTEND_URL"
        value = google_cloud_run_v2_service.frontend[0].uri
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
    google_cloud_run_v2_service.auth,
    google_cloud_run_v2_service.profile,
    google_cloud_run_v2_service.challenge,
    google_cloud_run_v2_service.application,
    google_cloud_run_v2_service.frontend,
    google_project_service.services["run.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# Serverless VPC Access Connector: Challenge
# ------------------------------------------------------------------------------
resource "google_vpc_access_connector" "challenge" {
  count         = var.deploy_services ? 1 : 0
  name          = "conecta-challenge-vpc"
  region        = var.region
  network       = var.challenge_vpc_network
  ip_cidr_range = var.challenge_vpc_connector_cidr
  min_instances = var.challenge_vpc_min_instances
  max_instances = var.challenge_vpc_max_instances
  machine_type  = "e2-micro"

  depends_on = [
    google_project_service.services["vpcaccess.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# 5. Microservice: Challenge (FastAPI + uv)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "challenge" {
  count               = var.deploy_services ? 1 : 0
  name                = "conecta-challenge"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    vpc_access {
      connector = google_vpc_access_connector.challenge[0].id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      image = "${local.artifact_repo_url}/challenge:${var.image_tag}"

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
        value = "postgresql+asyncpg://${var.db_user}:${local.db_password}@/${google_sql_database.challenges.name}?host=/cloudsql/${google_sql_database_instance.postgres.connection_name}"
      }
      env {
        name  = "JWT_PUBLIC_KEY"
        value = local.jwt_public_key
      }
      env {
        name  = "JWT_PUBLIC_KEY_PATH"
        value = "certs/jwt_public.pem"
      }
      env {
        name  = "STORAGE_AUTO_CREATE_BUCKET"
        value = "false"
      }
      env {
        name  = "STORAGE_BUCKET"
        value = google_storage_bucket.challenge_attachments.name
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
    google_sql_database.challenges,
    google_sql_user.db_user,
    google_project_service.services["run.googleapis.com"],
    google_vpc_access_connector.challenge
  ]
}

# ------------------------------------------------------------------------------
# 6. Microservice: Application (Django + DRF + uv)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "application" {
  count               = var.deploy_services ? 1 : 0
  name                = "conecta-application"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run_sa.email

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    containers {
      image = "${local.artifact_repo_url}/application:${var.image_tag}"

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
        name  = "DEBUG"
        value = "False"
      }
      env {
        name  = "ALLOWED_HOSTS"
        value = "*"
      }
      env {
        name  = "SECRET_KEY"
        value = var.django_secret_key
      }
      env {
        name  = "DATABASE_URL"
        value = "postgresql://${var.db_user}:${local.db_password}@/db_applications?host=/cloudsql/${google_sql_database_instance.postgres.connection_name}"
      }
      env {
        name  = "POSTGRES_DB"
        value = "db_applications"
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
      env {
        name  = "JWT_PUBLIC_KEY"
        value = local.jwt_public_key
      }
      env {
        name  = "CHALLENGE_SERVICE_URL"
        value = google_cloud_run_v2_service.challenge[0].uri
      }
      env {
        name  = "CHALLENGE_SERVICE_TIMEOUT_SECONDS"
        value = "5.0"
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
    google_cloud_run_v2_service.challenge,
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

resource "google_cloud_run_v2_service_iam_member" "public_challenge" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.challenge[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "public_application" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.application[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ------------------------------------------------------------------------------
# Service-to-Service Access Permissions (Gateway Runtime SA -> Microservices)
# ------------------------------------------------------------------------------

resource "google_cloud_run_v2_service_iam_member" "challenge_invoker" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.challenge[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_cloud_run_v2_service_iam_member" "application_invoker" {
  count    = var.deploy_services ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.application[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
