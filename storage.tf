# ==============================================================================
# Cloud Storage Bucket for Technical Attachments
# ==============================================================================

resource "google_storage_bucket" "challenge_attachments" {
  name          = "conecta-nexus-${var.environment}-challenge-attachments"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = var.environment != "prod"

  cors {
    origin          = var.cors_allowed_origins
    method          = ["GET", "PUT", "POST", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  labels = {
    project     = "conecta-nexus"
    environment = var.environment
    service     = "challenge"
  }

  depends_on = [
    google_project_service.services["storage.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# IAM Policy Binding for Cloud Run Service Account
# ------------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "challenge_attachments_admin" {
  bucket = google_storage_bucket.challenge_attachments.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
