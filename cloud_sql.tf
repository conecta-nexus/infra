# ==============================================================================
# Cloud SQL (PostgreSQL 16) Instance, Databases & Credentials
# ==============================================================================

resource "random_id" "db_suffix" {
  byte_length = 3
}

resource "random_password" "generated_password" {
  length  = 20
  special = false
}

locals {
  db_password = var.db_password != "" ? var.db_password : random_password.generated_password.result

  # All microservice databases to provision
  microservice_databases = [
    "db_auth",          # Auth microservice
    "db_profiles",      # Profile microservice
    "db_challenges",    # Challenge microservice
    "db_applications",  # Application microservice
    "db_moderation",    # Moderation microservice
    "db_notifications", # Notification microservice
  ]
}

resource "google_sql_database_instance" "postgres" {
  name             = "${var.db_instance_name}-${random_id.db_suffix.hex}"
  database_version = "POSTGRES_16"
  region           = var.region

  # Important for dev/class environments so destruction isn't blocked
  deletion_protection = false

  settings {
    tier              = var.db_tier
    disk_size         = 10
    disk_type         = "PD_SSD"
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled = true
    }

    backup_configuration {
      enabled    = true
      start_time = "04:00"
    }

    user_labels = {
      project     = "conecta-nexus"
      environment = var.environment
    }
  }

  depends_on = [
    google_project_service.services["sqladmin.googleapis.com"]
  ]
}

# Microservice Database User
resource "google_sql_user" "db_user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = local.db_password
}

# Provision databases for each microservice declaratively
resource "google_sql_database" "databases" {
  for_each = toset(local.microservice_databases)

  name     = each.key
  instance = google_sql_database_instance.postgres.name
}
