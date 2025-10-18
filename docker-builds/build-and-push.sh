#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Usage function
usage() {
    echo "Usage: $0 <app-name> <tag> [dockerfile-path]"
    echo ""
    echo "Examples:"
    echo "  $0 nodejs-app latest"
    echo "  $0 python-app v1.0.0"
    echo "  $0 nginx-custom production"
    echo "  $0 my-app v1.0 ./custom/Dockerfile"
    echo ""
    echo "Available apps in sample-apps/:"
    ls -1 sample-apps/ 2>/dev/null || echo "  (no sample apps found)"
    exit 1
}

# Check arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

APP_NAME=$1
TAG=$2
DOCKERFILE_PATH=${3:-""}

# Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-docker-swarm-app}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get AWS Account ID
print_status "Getting AWS configuration..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    print_error "Failed to get AWS Account ID. Please check your AWS credentials."
    exit 1
fi

ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
FULL_IMAGE_NAME=${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:${APP_NAME}-${TAG}

print_status "Configuration:"
print_status "  App Name: ${APP_NAME}"
print_status "  Tag: ${TAG}"
print_status "  Full Image: ${FULL_IMAGE_NAME}"

# Determine build context and Dockerfile
if [ -n "$DOCKERFILE_PATH" ]; then
    # Custom Dockerfile path provided
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        print_error "Dockerfile not found: $DOCKERFILE_PATH"
        exit 1
    fi
    BUILD_CONTEXT=$(dirname "$DOCKERFILE_PATH")
    DOCKERFILE_ARG="-f"
    DOCKERFILE_FILE="$DOCKERFILE_PATH"
    print_status "  Dockerfile: ${DOCKERFILE_PATH}"
    print_status "  Build Context: ${BUILD_CONTEXT}"
else
    # Look for app in sample-apps directory
    APP_DIR="${SCRIPT_DIR}/sample-apps/${APP_NAME}"
    if [ ! -d "$APP_DIR" ]; then
        print_error "Application directory not found: $APP_DIR"
        print_warning "Available apps:"
        ls -1 "${SCRIPT_DIR}/sample-apps/" 2>/dev/null || echo "  (no sample apps found)"
        exit 1
    fi
    
    DOCKERFILE="${APP_DIR}/Dockerfile"
    if [ ! -f "$DOCKERFILE" ]; then
        print_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi
    
    BUILD_CONTEXT="$APP_DIR"
    DOCKERFILE_ARG="-f"
    DOCKERFILE_FILE="$DOCKERFILE"
    print_status "  App Directory: ${APP_DIR}"
    print_status "  Dockerfile: ${DOCKERFILE}"
fi

# Login to ECR
print_status "Logging into ECR..."
./ecr-login.sh
if [ $? -ne 0 ]; then
    print_error "ECR login failed"
    exit 1
fi

# Build Docker image
print_status "Building Docker image..."
print_status "Command: docker build ${DOCKERFILE_ARG} ${DOCKERFILE_FILE} -t ${FULL_IMAGE_NAME} ${BUILD_CONTEXT}"

docker build ${DOCKERFILE_ARG} "${DOCKERFILE_FILE}" -t "${FULL_IMAGE_NAME}" "${BUILD_CONTEXT}"

if [ $? -eq 0 ]; then
    print_success "Docker image built successfully: ${FULL_IMAGE_NAME}"
else
    print_error "Docker build failed"
    exit 1
fi

# Tag with latest if not already latest
if [ "$TAG" != "latest" ]; then
    LATEST_IMAGE=${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:${APP_NAME}-latest
    print_status "Tagging image as latest: ${LATEST_IMAGE}"
    docker tag ${FULL_IMAGE_NAME} ${LATEST_IMAGE}
fi

# Push to ECR
print_status "Pushing image to ECR..."
docker push ${FULL_IMAGE_NAME}

if [ $? -eq 0 ]; then
    print_success "Image pushed successfully: ${FULL_IMAGE_NAME}"
else
    print_error "Docker push failed"
    exit 1
fi

# Push latest tag if created
if [ "$TAG" != "latest" ]; then
    print_status "Pushing latest tag..."
    docker push ${LATEST_IMAGE}
    if [ $? -eq 0 ]; then
        print_success "Latest tag pushed successfully: ${LATEST_IMAGE}"
    fi
fi

# Clean up local images (optional)
read -p "Remove local Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Removing local images..."
    docker rmi ${FULL_IMAGE_NAME} || true
    if [ "$TAG" != "latest" ]; then
        docker rmi ${LATEST_IMAGE} || true
    fi
    print_success "Local images removed"
fi

# Show final information
print_success "🎉 Build and push completed successfully!"
echo ""
echo "📋 Image Information:"
echo "  Registry: ${ECR_REGISTRY}"
echo "  Repository: ${ECR_REPOSITORY_NAME}"
echo "  Full Image: ${FULL_IMAGE_NAME}"
echo ""
echo "🚀 Next Steps:"
echo "  1. Deploy to Swarm: ./deploy-to-swarm.sh ${APP_NAME} ${TAG} <port> <replicas>"
echo "  2. Test locally: docker run -p <local-port>:<container-port> ${FULL_IMAGE_NAME}"
echo ""