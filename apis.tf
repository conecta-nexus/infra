# ==============================================================================
# Google Cloud APIs Enablement
# ==============================================================================

locals {
  required_services = [
    "artifactregistry.googleapis.com", # Artifact Registry for Docker images
    "cloudbuild.googleapis.com",       # Cloud Build for container builds
    "run.googleapis.com",              # Cloud Run for serverless container deployment
    "sqladmin.googleapis.com",         # Cloud SQL Admin API for database provisioning
    "iam.googleapis.com",              # Identity and Access Management
    "secretmanager.googleapis.com",    # Secret Manager (optional secret storage)
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.required_services)

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
