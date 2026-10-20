# ==============================================================================
# Terraform Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# Artifact Registry Outputs
# ------------------------------------------------------------------------------
output "artifact_registry_repository_name" {
  description = "Name of the created Artifact Registry repository."
  value       = google_artifact_registry_repository.docker_repo.name
}

output "artifact_registry_repository_url" {
  description = "Full Docker image repository prefix for pushing containers."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.name}"
}

# ------------------------------------------------------------------------------
# Cloud SQL Outputs
# ------------------------------------------------------------------------------
output "cloud_sql_instance_name" {
  description = "The name of the Cloud SQL PostgreSQL instance."
  value       = google_sql_database_instance.postgres.name
}

output "cloud_sql_connection_name" {
  description = "Connection name for the Cloud SQL instance (used by Cloud Run and proxy)."
  value       = google_sql_database_instance.postgres.connection_name
}

output "cloud_sql_public_ip" {
  description = "The public IPv4 address of the Cloud SQL instance."
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "database_user" {
  description = "Database username configured for microservices."
  value       = var.db_user
}

output "database_password" {
  description = "Database user password (sensitive)."
  value       = local.db_password
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Cloud Run Service URLs (Phase 2)
# ------------------------------------------------------------------------------
output "gateway_url" {
  description = "Public entrypoint URL for the API Gateway."
  value       = var.deploy_services ? google_cloud_run_v2_service.gateway[0].uri : "Not deployed yet (Phase 1). Run with -var='deploy_services=true' after pushing images."
}

output "frontend_url" {
  description = "Public URL for the Nuxt 4 Frontend service."
  value       = var.deploy_services ? google_cloud_run_v2_service.frontend[0].uri : "Not deployed yet (Phase 1)."
}

output "auth_service_url" {
  description = "Direct URL for the Auth microservice."
  value       = var.deploy_services ? google_cloud_run_v2_service.auth[0].uri : "Not deployed yet (Phase 1)."
}

output "profile_service_url" {
  description = "Direct URL for the Profile microservice."
  value       = var.deploy_services ? google_cloud_run_v2_service.profile[0].uri : "Not deployed yet (Phase 1)."
}
