# ==============================================================================
# Input Variables for Conecta Nexus Infrastructure
# ==============================================================================

variable "project_id" {
  type        = string
  description = "The Google Cloud Platform (GCP) Project ID."
}

variable "region" {
  type        = string
  description = "The GCP region for regional resources (Artifact Registry, Cloud Run, Cloud SQL)."
  default     = "us-central1"
}

variable "environment" {
  type        = string
  description = "Environment label / identifier (e.g. dev, staging, prod)."
  default     = "dev"
}

# ------------------------------------------------------------------------------
# Artifact Registry
# ------------------------------------------------------------------------------

variable "artifact_registry_repo_id" {
  type        = string
  description = "Repository name in Google Artifact Registry for container images."
  default     = "conecta-nexus"
}

# ------------------------------------------------------------------------------
# Cloud SQL (PostgreSQL)
# ------------------------------------------------------------------------------

variable "db_instance_name" {
  type        = string
  description = "Base name for the Cloud SQL PostgreSQL instance."
  default     = "conecta-nexus-pg"
}

variable "db_tier" {
  type        = string
  description = "Machine type for the Cloud SQL instance (e.g., db-f1-micro, db-g1-small, db-custom-1-3840)."
  default     = "db-f1-micro"
}

variable "db_user" {
  type        = string
  description = "Main PostgreSQL username for microservice database access."
  default     = "postgres"
}

variable "db_password" {
  type        = string
  description = "Password for the database user. If left empty, a secure random password is generated."
  sensitive   = true
  default     = ""
}

# ------------------------------------------------------------------------------
# Deployment Strategy (Partial Deployment Flag)
# ------------------------------------------------------------------------------

variable "deploy_services" {
  type        = bool
  description = "When false (Phase 1), only APIs, Artifact Registry, IAM, and Cloud SQL are created. When true (Phase 2), Cloud Run services are deployed using the pushed images."
  default     = false
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy to Cloud Run."
  default     = "latest"
}

variable "django_secret_key" {
  type        = string
  description = "Secret key for Django-based microservices (profile, etc.)."
  sensitive   = true
  default     = "django-insecure-conecta-nexus-cloud-production-secret"
}
