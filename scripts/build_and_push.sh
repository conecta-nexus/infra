#!/usr/bin/env bash
# ==============================================================================
# Conecta Nexus - Build & Push Container Images to GCP Artifact Registry
# ==============================================================================
# Usage:
#   ./scripts/build_and_push.sh [PROJECT_ID] [REGION] [REPO_ID] [TAG]
#
# Examples:
#   ./scripts/build_and_push.sh
#   ./scripts/build_and_push.sh my-gcp-project us-central1 conecta-nexus latest
# ==============================================================================

set -euo pipefail

# Text formatting
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}================================================================${RESET}"
echo -e "${BOLD}${CYAN}   Conecta Nexus - Build & Push Container Images (Cloud Build)   ${RESET}"
echo -e "${BOLD}${CYAN}================================================================${RESET}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${INFRA_DIR}/.." && pwd)"

# Verify gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}[ERROR] 'gcloud' CLI is not found in your PATH.${RESET}"
    echo -e "Please install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Detect Project ID
PROJECT_ID="${1:-}"
if [ -z "${PROJECT_ID}" ]; then
    # Try reading from terraform.tfvars or gcloud config
    if [ -f "${INFRA_DIR}/terraform.tfvars" ]; then
        PROJECT_ID=$(grep -E '^\s*project_id\s*=' "${INFRA_DIR}/terraform.tfvars" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)
    fi
    if [ -z "${PROJECT_ID}" ]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
    fi
fi

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
    echo -e "${RED}[ERROR] Could not determine GCP Project ID.${RESET}"
    echo -e "Please provide it as the first argument or set it in gcloud:"
    echo -e "  ./scripts/build_and_push.sh <PROJECT_ID> [REGION] [REPO_ID] [TAG]"
    exit 1
fi

REGION="${2:-}"
if [ -z "${REGION}" ]; then
    if [ -f "${INFRA_DIR}/terraform.tfvars" ]; then
        REGION=$(grep -E '^\s*region\s*=' "${INFRA_DIR}/terraform.tfvars" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)
    fi
    REGION="${REGION:-us-central1}"
fi

REPO_ID="${3:-}"
if [ -z "${REPO_ID}" ]; then
    if [ -f "${INFRA_DIR}/terraform.tfvars" ]; then
        REPO_ID=$(grep -E '^\s*artifact_registry_repo_id\s*=' "${INFRA_DIR}/terraform.tfvars" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)
    fi
    REPO_ID="${REPO_ID:-conecta-nexus}"
fi

TAG="${4:-}"
if [ -z "${TAG}" ]; then
    if [ -f "${INFRA_DIR}/terraform.tfvars" ]; then
        TAG=$(grep -E '^\s*image_tag\s*=' "${INFRA_DIR}/terraform.tfvars" | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)
    fi
    TAG="${TAG:-latest}"
fi

REGISTRY_PREFIX="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_ID}"

echo -e "  ${BOLD}GCP Project:${RESET}        ${GREEN}${PROJECT_ID}${RESET}"
echo -e "  ${BOLD}Region:${RESET}             ${GREEN}${REGION}${RESET}"
echo -e "  ${BOLD}Artifact Registry:${RESET}  ${GREEN}${REPO_ID}${RESET}"
echo -e "  ${BOLD}Image Tag:${RESET}          ${GREEN}${TAG}${RESET}"
echo -e "  ${BOLD}Destination Prefix:${RESET} ${CYAN}${REGISTRY_PREFIX}${RESET}"
echo -e "----------------------------------------------------------------"

# Current microservices to build and push
SERVICES=("auth" "profile" "frontend" "gateway")

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="${ROOT_DIR}/${SERVICE}"
    DEST_IMAGE="${REGISTRY_PREFIX}/${SERVICE}:${TAG}"

    echo -e "\n${BOLD}${YELLOW}[+] Building & Pushing: ${SERVICE}...${RESET}"
    echo -e "    Context: ${SERVICE_DIR}"
    echo -e "    Target:  ${DEST_IMAGE}"

    if [ ! -d "${SERVICE_DIR}" ]; then
        echo -e "${RED}[ERROR] Directory '${SERVICE_DIR}' not found. Skipping.${RESET}"
        continue
    fi

    if [ ! -f "${SERVICE_DIR}/Dockerfile" ]; then
        echo -e "${RED}[ERROR] Dockerfile not found in '${SERVICE_DIR}'. Skipping.${RESET}"
        continue
    fi

    # Submit build to Google Cloud Build (handles building remotely in GCP without requiring local Docker daemon)
    echo -e "    Submitting build to Google Cloud Build..."
    gcloud builds submit "${SERVICE_DIR}" \
        --project="${PROJECT_ID}" \
        --tag="${DEST_IMAGE}" \
        --timeout=20m

    echo -e "${GREEN}✓ Successfully built and pushed ${SERVICE}!${RESET}"
done

echo -e "\n${BOLD}${GREEN}================================================================${RESET}"
echo -e "${BOLD}${GREEN}   All microservice images pushed successfully!                 ${RESET}"
echo -e "${BOLD}${GREEN}================================================================${RESET}"
echo -e "You can now run Phase 2 of Terraform deployment:"
echo -e "  ${CYAN}terraform apply -var=\"deploy_services=true\"${RESET}\n"
