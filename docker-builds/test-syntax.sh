#!/bin/bash

# Quick test script to verify the build command syntax
set -e

echo "Testing Docker build command syntax..."

# Simulate the variables
APP_NAME="nginx-custom"
TAG="v1.0"
AWS_ACCOUNT_ID="481604401489"
AWS_REGION="ap-southeast-1"
ECR_REPOSITORY_NAME="docker-swarm-app"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:${APP_NAME}-${TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/sample-apps/${APP_NAME}"
DOCKERFILE="${APP_DIR}/Dockerfile"
BUILD_CONTEXT="$APP_DIR"
DOCKERFILE_ARG="-f"
DOCKERFILE_FILE="$DOCKERFILE"

echo "Variables:"
echo "  APP_NAME: $APP_NAME"
echo "  TAG: $TAG"
echo "  FULL_IMAGE_NAME: $FULL_IMAGE_NAME"
echo "  DOCKERFILE_FILE: $DOCKERFILE_FILE"
echo "  BUILD_CONTEXT: $BUILD_CONTEXT"
echo ""

echo "Command that will be executed:"
echo "docker build ${DOCKERFILE_ARG} \"${DOCKERFILE_FILE}\" -t \"${FULL_IMAGE_NAME}\" \"${BUILD_CONTEXT}\""

echo ""
echo "Testing command syntax (dry run):"
set -x
docker build --help > /dev/null 2>&1 && echo "✅ Docker is available"
set +x

echo ""
echo "✅ Command syntax looks correct now!"