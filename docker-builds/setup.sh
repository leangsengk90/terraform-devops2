#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🔧 Setting up Docker Builds environment..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make all shell scripts executable
print_status "Making scripts executable..."
find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \;
print_success "All scripts are now executable"

# Check prerequisites
print_status "Checking prerequisites..."

# Check Docker
if command -v docker &> /dev/null; then
    print_success "Docker is installed: $(docker --version)"
else
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    print_success "AWS CLI is installed: $(aws --version)"
else
    print_error "AWS CLI is not installed or not in PATH"
    exit 1
fi

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "ap-southeast-1")
    print_success "AWS credentials are configured (Account: $AWS_ACCOUNT_ID, Region: $AWS_REGION)"
else
    print_error "AWS credentials are not configured"
    exit 1
fi

# Test Docker daemon
if docker info &> /dev/null; then
    print_success "Docker daemon is running"
else
    print_error "Docker daemon is not running"
    exit 1
fi

# Check if ECR repository exists
ECR_REPOSITORY_NAME="docker-swarm-app"
if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" &> /dev/null; then
    ECR_URI=$(aws ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" --query 'repositories[0].repositoryUri' --output text)
    print_success "ECR repository exists: $ECR_URI"
else
    print_warning "ECR repository '$ECR_REPOSITORY_NAME' not found. Make sure to deploy the docker-swarm infrastructure first."
fi

print_status "📋 Available applications:"
for app_dir in "$SCRIPT_DIR/sample-apps"/*; do
    if [ -d "$app_dir" ]; then
        app_name=$(basename "$app_dir")
        if [ -f "$app_dir/Dockerfile" ]; then
            echo "  ✅ $app_name (Dockerfile found)"
        else
            echo "  ❌ $app_name (No Dockerfile)"
        fi
    fi
done

print_status "🚀 Available commands:"
echo "  ./ecr-login.sh                           - Login to ECR"
echo "  ./build-and-push.sh <app> <tag>          - Build and push single app"
echo "  ./scripts/build-all.sh                   - Build and push all apps"
echo "  ./deploy-to-swarm.sh <app> <tag> <port> <replicas> - Deploy to swarm"
echo "  ./scripts/cleanup-images.sh              - Clean up local Docker images"

print_success "🎉 Docker Builds environment is ready!"
print_status "Next steps:"
echo "1. Run './ecr-login.sh' to authenticate with ECR"
echo "2. Build an app: './build-and-push.sh nodejs-app latest'"
echo "3. Deploy to swarm: './deploy-to-swarm.sh nodejs-app latest 8080 3'"