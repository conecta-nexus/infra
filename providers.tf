# ==============================================================================
# Google Cloud Provider Configuration
# ==============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
}
