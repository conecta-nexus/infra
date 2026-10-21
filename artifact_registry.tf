# ==============================================================================
# Google Artifact Registry Repository
# ==============================================================================

resource "google_artifact_registry_repository" "docker_repo" {
  provider = google

  location      = var.region
  repository_id = var.artifact_registry_repo_id
  description   = "Docker container registry for Conecta Nexus microservices"
  format        = "DOCKER"

  labels = {
    project     = "conecta-nexus"
    environment = var.environment
  }

  depends_on = [
    google_project_service.services["artifactregistry.googleapis.com"]
  ]
}

locals {
  artifact_repo_url = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.name}"
}
