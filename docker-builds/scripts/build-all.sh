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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_BUILDS_DIR="$(dirname "$SCRIPT_DIR")"

print_status "Building all applications in sample-apps/"

# Change to docker-builds directory
cd "$DOCKER_BUILDS_DIR"

# Find all sample applications
SAMPLE_APPS_DIR="sample-apps"
if [ ! -d "$SAMPLE_APPS_DIR" ]; then
    print_error "Sample apps directory not found: $SAMPLE_APPS_DIR"
    exit 1
fi

# Get list of applications
APPS=$(ls -1 "$SAMPLE_APPS_DIR")
if [ -z "$APPS" ]; then
    print_warning "No applications found in $SAMPLE_APPS_DIR"
    exit 0
fi

print_status "Found applications: $(echo $APPS | tr '\n' ' ')"

# Build each application
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_APPS=()

for APP in $APPS; do
    APP_DIR="$SAMPLE_APPS_DIR/$APP"
    
    # Check if directory contains a Dockerfile
    if [ ! -f "$APP_DIR/Dockerfile" ]; then
        print_warning "Skipping $APP (no Dockerfile found)"
        continue
    fi
    
    print_status "Building application: $APP"
    
    # Build and push with latest tag
    if ./build-and-push.sh "$APP" "latest"; then
        print_success "Successfully built and pushed: $APP"
        ((SUCCESS_COUNT++))
    else
        print_error "Failed to build: $APP"
        ((FAILED_COUNT++))
        FAILED_APPS+=("$APP")
    fi
    
    echo ""
done

# Summary
print_status "Build Summary:"
print_status "  Total applications: $((SUCCESS_COUNT + FAILED_COUNT))"
print_success "  Successful builds: $SUCCESS_COUNT"

if [ $FAILED_COUNT -gt 0 ]; then
    print_error "  Failed builds: $FAILED_COUNT"
    print_error "  Failed apps: ${FAILED_APPS[*]}"
    exit 1
else
    print_success "🎉 All applications built successfully!"
fi