#!/usr/bin/env bash
# ==============================================================================
# Conecta Nexus - End-to-End GCP Deployment Automation
# ==============================================================================
# Executes the three-phase deployment workflow:
#   1. Phase 1 (Infra Foundation): APIs, Artifact Registry, IAM, Cloud SQL & DBs
#   2. Phase 2 (Image Build): Builds & pushes Docker containers via Cloud Build
#   3. Phase 3 (Cloud Run Deployment): Provisions microservice services & Gateway
# ==============================================================================

set -euo pipefail

# Text formatting
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
RED="\033[31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${INFRA_DIR}"

echo -e "${BOLD}${MAGENTA}================================================================${RESET}"
echo -e "${BOLD}${MAGENTA}      Conecta Nexus - Multi-Phase GCP Cloud Deployment          ${RESET}"
echo -e "${BOLD}${MAGENTA}================================================================${RESET}"

# 1. Verification
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}[ERROR] 'terraform' is not installed or not in PATH.${RESET}"
    exit 1
fi

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}[!] 'terraform.tfvars' not found.${RESET}"
    if [ -f "terraform.tfvars.example" ]; then
        echo -e "    Copying terraform.tfvars.example -> terraform.tfvars..."
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${RED}[ACTION REQUIRED] Please edit 'terraform.tfvars' with your actual GCP project_id and re-run this script!${RESET}"
        exit 1
    fi
fi

# 2. Phase 1: Foundational Infrastructure (Artifact Registry, IAM, Cloud SQL)
echo -e "\n${BOLD}${CYAN}>>> [Phase 1/3] Provisioning Foundational Infrastructure...${RESET}"
echo -e "    (APIs, Artifact Registry, Cloud SQL PostgreSQL, IAM)"
terraform init
terraform apply -var="deploy_services=false" -auto-approve

# 3. Phase 2: Build and Push Images using Cloud Build
echo -e "\n${BOLD}${CYAN}>>> [Phase 2/3] Building and Pushing Container Images...${RESET}"
"${SCRIPT_DIR}/build_and_push.sh"

# 4. Phase 3: Cloud Run Microservices & Gateway Deployment
echo -e "\n${BOLD}${CYAN}>>> [Phase 3/3] Deploying Cloud Run Services & API Gateway...${RESET}"
terraform apply -var="deploy_services=true" -auto-approve

# 5. Display Outputs & Presentation Links
echo -e "\n${BOLD}${GREEN}================================================================${RESET}"
echo -e "${BOLD}${GREEN}   DEPLOYMENT COMPLETED SUCCESSFULLY!                           ${RESET}"
echo -e "${BOLD}${GREEN}================================================================${RESET}"
terraform output
