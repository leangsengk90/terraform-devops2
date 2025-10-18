# Docker Builds for ECR

This directory contains Docker applications and scripts for building, tagging, and pushing images to AWS ECR (Elastic Container Registry).

## Directory Structure

```
docker-builds/
├── README.md                    # This file
├── build-and-push.sh          # Main build and push script
├── ecr-login.sh               # ECR authentication script
├── deploy-to-swarm.sh         # Deploy built images to Docker Swarm
├── scripts/                   # Automation scripts
│   ├── build-all.sh          # Build all applications
│   ├── build-single.sh       # Build single application
│   └── cleanup-images.sh     # Clean up local Docker images
└── sample-apps/              # Sample applications
    ├── nodejs-app/           # Node.js web application
    ├── python-app/           # Python Flask application
    └── nginx-custom/         # Custom Nginx with static content
```

## Prerequisites

1. **AWS CLI configured** with ECR permissions
2. **Docker installed** and running
3. **ECR repository** created (done by Terraform in docker-swarm module)
4. **Docker Swarm cluster** running (deployed via ../docker-swarm/)

## Quick Start

### 1. Login to ECR

```bash
./ecr-login.sh
```

### 2. Build and Push Single App

```bash
./build-and-push.sh nodejs-app latest
```

### 3. Build and Push All Apps

```bash
./scripts/build-all.sh
```

### 4. Deploy to Docker Swarm

```bash
./deploy-to-swarm.sh nodejs-app latest 8080 3
```

## Available Applications

### Node.js App (`nodejs-app/`)

- **Description**: Simple Express.js web server
- **Port**: 3000
- **Health Check**: `/health`
- **Features**: JSON API, health monitoring

### Python App (`python-app/`)

- **Description**: Flask web application
- **Port**: 5000
- **Health Check**: `/health`
- **Features**: REST API, metrics endpoint

### Custom Nginx (`nginx-custom/`)

- **Description**: Nginx with custom static content
- **Port**: 80
- **Health Check**: `/`
- **Features**: Custom HTML pages, optimized config

## Scripts Reference

### `build-and-push.sh`

Main script for building and pushing images to ECR.

**Usage:**

```bash
./build-and-push.sh <app-name> <tag> [dockerfile-path]
```

**Examples:**

```bash
# Build and push with latest tag
./build-and-push.sh nodejs-app latest

# Build and push with version tag
./build-and-push.sh python-app v1.0.0

# Build with custom Dockerfile
./build-and-push.sh custom-app v1.0 ./path/to/Dockerfile
```

### `deploy-to-swarm.sh`

Deploy built images to Docker Swarm cluster.

**Usage:**

```bash
./deploy-to-swarm.sh <app-name> <tag> <port> <replicas>
```

**Examples:**

```bash
# Deploy Node.js app with 3 replicas on port 8080
./deploy-to-swarm.sh nodejs-app latest 8080 3

# Deploy Python app with 2 replicas on port 8081
./deploy-to-swarm.sh python-app v1.0.0 8081 2
```

## Environment Variables

The scripts use these environment variables (with defaults):

```bash
# AWS Configuration
AWS_REGION=ap-southeast-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECR Configuration
ECR_REPOSITORY_NAME=docker-swarm-app
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Docker Swarm Configuration
SWARM_MASTER_IP=<auto-detected-from-terraform-output>
```

## Advanced Usage

### Custom Build Context

```bash
# Build with specific build context
docker build -f sample-apps/nodejs-app/Dockerfile \
    -t ${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:nodejs-custom \
    ./sample-apps/nodejs-app/
```

### Multi-stage Builds

```bash
# Build with build arguments
docker build \
    --build-arg NODE_ENV=production \
    --build-arg BUILD_VERSION=1.0.0 \
    -t ${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:nodejs-prod \
    ./sample-apps/nodejs-app/
```

### Local Testing

```bash
# Test locally before pushing
docker run -p 3000:3000 ${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:nodejs-app-latest

# Check health endpoint
curl http://localhost:3000/health
```

## Troubleshooting

### ECR Authentication Issues

```bash
# Check AWS credentials
aws sts get-caller-identity

# Force ECR login
aws ecr get-login-password --region ap-southeast-1 | \
    docker login --username AWS --password-stdin \
    ${ECR_REGISTRY}
```

### Docker Build Issues

```bash
# Check Docker daemon
docker version

# Clean up build cache
docker builder prune

# Build with verbose output
docker build --no-cache --progress=plain -t image:tag .
```

### Deployment Issues

```bash
# Check swarm status
ssh -i ~/.ssh/docker-swarm-key ec2-user@${SWARM_MASTER_IP} "docker node ls"

# Check service status
ssh -i ~/.ssh/docker-swarm-key ec2-user@${SWARM_MASTER_IP} "docker service ls"
```

## Best Practices

### Image Tagging Strategy

- **latest**: Current development version
- **v1.0.0**: Semantic versioning for releases
- **main-abc123**: Git commit-based tags
- **prod-YYYYMMDD**: Date-based production tags

### Security Considerations

- **Multi-stage builds**: Minimize final image size
- **Non-root users**: Run containers as non-root
- **Minimal base images**: Use alpine or distroless images
- **Vulnerability scanning**: ECR scan on push enabled

### Performance Optimization

- **Layer caching**: Optimize Dockerfile layer order
- **Build cache**: Use Docker BuildKit
- **Image size**: Minimize dependencies and files
- **Compression**: Use appropriate compression

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and Push
        run: |
          cd docker-builds
          ./ecr-login.sh
          ./build-and-push.sh nodejs-app ${GITHUB_SHA::7}
          ./deploy-to-swarm.sh nodejs-app ${GITHUB_SHA::7} 8080 3
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'cd docker-builds && ./build-and-push.sh nodejs-app ${BUILD_NUMBER}'
            }
        }
        stage('Deploy') {
            steps {
                sh 'cd docker-builds && ./deploy-to-swarm.sh nodejs-app ${BUILD_NUMBER} 8080 3'
            }
        }
    }
}
```
