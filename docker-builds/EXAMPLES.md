# Docker Builds - Usage Examples

This document provides practical examples for using the Docker builds system.

## Prerequisites Setup

First, run the setup script to ensure everything is configured:

```bash
cd docker-builds
./setup.sh
```

## Basic Workflow Examples

### 1. Build and Deploy Node.js Application

```bash
# Step 1: Login to ECR
./ecr-login.sh

# Step 2: Build and push the Node.js app
./build-and-push.sh nodejs-app latest

# Step 3: Deploy to Docker Swarm (3 replicas on port 8080)
./deploy-to-swarm.sh nodejs-app latest 8080 3

# Step 4: Check deployment
curl http://<LOAD_BALANCER_URL>:8080/
curl http://<LOAD_BALANCER_URL>:8080/health
```

### 2. Build and Deploy Python Application

```bash
# Build and push Python Flask app
./build-and-push.sh python-app v1.0.0

# Deploy with 2 replicas on port 8081
./deploy-to-swarm.sh python-app v1.0.0 8081 2

# Test the API
curl http://<LOAD_BALANCER_URL>:8081/api/products
curl http://<LOAD_BALANCER_URL>:8081/health
```

### 3. Build and Deploy Custom Nginx

```bash
# Build custom Nginx with static content
./build-and-push.sh nginx-custom latest

# Deploy with 2 replicas on port 80
./deploy-to-swarm.sh nginx-custom latest 80 2

# Test the web server
curl http://<LOAD_BALANCER_URL>/
curl http://<LOAD_BALANCER_URL>/about
```

## Advanced Usage Examples

### Build All Applications at Once

```bash
# Build and push all applications with latest tag
./scripts/build-all.sh
```

### Version-based Deployment

```bash
# Build with semantic version
./build-and-push.sh nodejs-app v1.2.3

# Deploy specific version
./deploy-to-swarm.sh nodejs-app v1.2.3 8080 3
```

### Development Workflow

```bash
# Build with development tag
./build-and-push.sh nodejs-app dev-$(date +%Y%m%d)

# Quick deploy for testing
./deploy-to-swarm.sh nodejs-app dev-$(date +%Y%m%d) 8080 1
```

## Multi-Service Deployment Example

Deploy multiple services with different configurations:

```bash
# Login once
./ecr-login.sh

# Build all applications
./build-and-push.sh nodejs-app latest
./build-and-push.sh python-app latest
./build-and-push.sh nginx-custom latest

# Deploy services on different ports
./deploy-to-swarm.sh nodejs-app latest 8080 3    # Node.js API
./deploy-to-swarm.sh python-app latest 8081 2    # Python API
./deploy-to-swarm.sh nginx-custom latest 80 2    # Frontend
```

## Testing Deployed Services

### Health Check All Services

```bash
# Get load balancer URL from Terraform output
LOAD_BALANCER_URL=$(cd ../docker-swarm && terraform output -raw load_balancer_url)

# Test all health endpoints
echo "Testing Node.js app..."
curl -s "$LOAD_BALANCER_URL:8080/health" | jq .

echo "Testing Python app..."
curl -s "$LOAD_BALANCER_URL:8081/health" | jq .

echo "Testing Nginx..."
curl -s "$LOAD_BALANCER_URL/health" | jq .
```

### Load Testing Example

```bash
# Simple load test with curl
for i in {1..10}; do
  curl -s "$LOAD_BALANCER_URL:8080/" &
done
wait

# Monitor service scaling
ssh -i ~/.ssh/docker-swarm-key ec2-user@<MASTER_IP> "docker service ls"
```

## Docker Swarm Management

### SSH to Master Node

```bash
# Get master IP from Terraform
MASTER_IP=$(cd ../docker-swarm && terraform output -raw swarm_master_public_ip)

# SSH to master
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP

# Once connected, you can run Docker Swarm commands:
# docker service ls
# docker node ls
# docker service ps <service-name>
# docker service logs <service-name>
```

### Scaling Services

```bash
# Scale Node.js service to 5 replicas
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service scale nodejs-app=5"

# Scale Python service to 1 replica
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service scale python-app=1"
```

### Rolling Updates

```bash
# Build new version
./build-and-push.sh nodejs-app v1.1.0

# Update service with rolling deployment
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service update --image $ECR_REGISTRY/docker-swarm-app:nodejs-app-v1.1.0 nodejs-app"
```

## Cleanup Examples

### Remove Specific Service

```bash
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service rm nodejs-app"
```

### Clean Local Images

```bash
# Remove all local docker-swarm related images
./scripts/cleanup-images.sh

# Or manually remove specific images
docker rmi $(docker images "*docker-swarm-app*" -q)
```

### Remove All Services

```bash
# Remove all deployed services
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service ls --format '{{.Name}}' | xargs -r docker service rm"
```

## Troubleshooting Examples

### Debug Build Issues

```bash
# Build with verbose output
docker build --no-cache --progress=plain \
  -t test-build ./sample-apps/nodejs-app/

# Check build logs
docker logs <container-id>
```

### Debug Deployment Issues

```bash
# Check service status
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service ps nodejs-app --no-trunc"

# Check service logs
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker service logs nodejs-app"

# Check node status
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker node ls"
```

### Debug Network Issues

```bash
# Test connectivity from within swarm
ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP \
  "docker run --rm --network host nicolaka/netshoot curl localhost:8080/health"

# Check load balancer targets
aws elbv2 describe-target-health \
  --target-group-arn $(cd ../docker-swarm && terraform output -json | jq -r '.target_group_arns.value[0]')
```

## CI/CD Integration Examples

### GitHub Actions Workflow

```yaml
name: Build and Deploy
on:
  push:
    branches: [main]
    paths: ["docker-builds/**"]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-southeast-1

      - name: Deploy applications
        run: |
          cd docker-builds
          ./ecr-login.sh
          ./scripts/build-all.sh
          ./deploy-to-swarm.sh nodejs-app latest 8080 3
```

### GitLab CI Pipeline

```yaml
stages:
  - build
  - deploy

build:
  stage: build
  script:
    - cd docker-builds
    - ./ecr-login.sh
    - ./build-and-push.sh nodejs-app $CI_COMMIT_SHORT_SHA

deploy:
  stage: deploy
  script:
    - cd docker-builds
    - ./deploy-to-swarm.sh nodejs-app $CI_COMMIT_SHORT_SHA 8080 3
  when: manual
```

## Performance Testing

### Load Testing with Apache Bench

```bash
# Install apache2-utils for ab command
# Ubuntu/Debian: sudo apt-get install apache2-utils
# macOS: brew install httpd

# Test with 1000 requests, 10 concurrent
ab -n 1000 -c 10 http://$LOAD_BALANCER_URL:8080/

# Test API endpoint
ab -n 500 -c 5 http://$LOAD_BALANCER_URL:8081/api/products
```

### Monitoring During Load Tests

```bash
# Monitor in real-time
watch -n 2 "ssh -i ~/.ssh/docker-swarm-key ec2-user@$MASTER_IP 'docker service ls'"

# Check auto-scaling
watch -n 5 "aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names docker-swarm-swarm-workers \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Current:length(Instances)}'"
```
