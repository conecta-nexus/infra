# ==============================================================================
# Service Accounts & IAM Permissions
# ==============================================================================

# Service Account dedicated to running Conecta Nexus Cloud Run services
resource "google_service_account" "cloud_run_sa" {
  account_id   = "sa-conecta-runner"
  display_name = "Conecta Nexus Cloud Run Runtime SA"
  description  = "Assigned to Cloud Run services to allow Cloud SQL connection and logging"

  depends_on = [
    google_project_service.services["iam.googleapis.com"]
  ]
}

# Grant Cloud SQL Client permission so Cloud Run instances can connect via Cloud SQL Auth Proxy
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Grant Logging permission
resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Grant Artifact Registry Reader to ensure Cloud Run can pull images
resource "google_project_iam_member" "artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
