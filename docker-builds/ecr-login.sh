#!/bin/bash

# ECR Login Script
# Authenticates Docker client with AWS ECR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check AWS credentials
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        log_error "Unable to get AWS Account ID. Check your AWS credentials."
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Login to ECR
ecr_login() {
    log_info "Logging into ECR registry: $ECR_REGISTRY"
    
    # Get ECR login token and login to Docker
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
        log_success "Successfully logged into ECR"
    else
        log_error "Failed to login to ECR"
        exit 1
    fi
}

# Verify ECR repository exists
verify_repository() {
    local repo_name=${1:-docker-swarm-app}
    
    log_info "Verifying ECR repository: $repo_name"
    
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &> /dev/null; then
        log_success "ECR repository '$repo_name' exists"
    else
        log_warning "ECR repository '$repo_name' does not exist"
        log_info "You may need to create it with: aws ecr create-repository --repository-name $repo_name --region $AWS_REGION"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "     Docker ECR Login Script"
    echo "======================================"
    echo
    
    validate_prerequisites
    echo
    
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    log_info "AWS Region: $AWS_REGION"
    log_info "ECR Registry: $ECR_REGISTRY"
    echo
    
    ecr_login
    echo
    
    verify_repository "docker-swarm-app"
    echo
    
    log_success "ECR login completed successfully!"
    echo
    echo "You can now build and push images using:"
    echo "  docker build -t $ECR_REGISTRY/docker-swarm-app:tag ."
    echo "  docker push $ECR_REGISTRY/docker-swarm-app:tag"
}

# Run main function
main "$@"