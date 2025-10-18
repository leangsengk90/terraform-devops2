#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo "This is a wrapper around the main build-and-push.sh script"
    echo "for building individual applications."
    echo ""
    echo "Examples:"
    echo "  $0 nodejs-app v1.0.0"
    echo "  $0 python-app latest"
    echo "  $0 my-app v1.0 ./path/to/Dockerfile"
    exit 1
}

# Check arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

APP_NAME=$1
TAG=$2
DOCKERFILE_PATH=${3:-""}

# Get script directory and navigate to docker-builds
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_BUILDS_DIR="$(dirname "$SCRIPT_DIR")"

print_status "Building single application: $APP_NAME"
print_status "Tag: $TAG"

# Change to docker-builds directory
cd "$DOCKER_BUILDS_DIR"

# Call main build script
if [ -n "$DOCKERFILE_PATH" ]; then
    ./build-and-push.sh "$APP_NAME" "$TAG" "$DOCKERFILE_PATH"
else
    ./build-and-push.sh "$APP_NAME" "$TAG"
fi

if [ $? -eq 0 ]; then
    print_success "🎉 Build completed successfully for $APP_NAME:$TAG"
else
    print_error "Build failed for $APP_NAME:$TAG"
    exit 1
fi