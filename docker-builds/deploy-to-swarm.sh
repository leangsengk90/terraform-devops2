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
    echo "Usage: $0 <app-name> <tag> <port> <replicas> [service-name]"
    echo ""
    echo "Arguments:"
    echo "  app-name    Application name (matches ECR image name)"
    echo "  tag         Image tag to deploy"
    echo "  port        Port to expose (e.g., 8080)"
    echo "  replicas    Number of service replicas"
    echo "  service-name Optional service name (default: app-name)"
    echo ""
    echo "Examples:"
    echo "  $0 nodejs-app latest 8080 3"
    echo "  $0 python-app v1.0.0 8081 2"
    echo "  $0 nginx-custom latest 8082 4 my-nginx"
    exit 1
}

# Check arguments
if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    usage
fi

APP_NAME=$1
TAG=$2
PORT=$3
REPLICAS=$4
SERVICE_NAME=${5:-$APP_NAME}

# Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-docker-swarm-app}
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/docker-swarm-key}

print_status "Deployment Configuration:"
print_status "  App Name: ${APP_NAME}"
print_status "  Tag: ${TAG}"
print_status "  Service Name: ${SERVICE_NAME}"
print_status "  Port: ${PORT}"
print_status "  Replicas: ${REPLICAS}"

# Get AWS Account ID and construct image name
print_status "Getting AWS configuration..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    print_error "Failed to get AWS Account ID. Please check your AWS credentials."
    exit 1
fi

ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
FULL_IMAGE_NAME=${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:${APP_NAME}-${TAG}

print_status "  Image: ${FULL_IMAGE_NAME}"

# Get Swarm Master IP from Terraform output
print_status "Getting Docker Swarm master IP..."
cd ../docker-swarm 2>/dev/null || {
    print_error "Cannot find docker-swarm directory. Please run this from the docker-builds directory."
    exit 1
}

SWARM_MASTER_IP=$(terraform output -raw swarm_master_public_ip 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$SWARM_MASTER_IP" ]; then
    print_error "Failed to get Swarm master IP. Make sure Docker Swarm is deployed."
    exit 1
fi

cd - > /dev/null
print_status "  Swarm Master IP: ${SWARM_MASTER_IP}"

# Check SSH key
if [ ! -f "$SSH_KEY_PATH" ]; then
    print_error "SSH key not found: $SSH_KEY_PATH"
    print_warning "Please ensure you have the SSH key for accessing the Swarm master."
    exit 1
fi

print_status "  SSH Key: ${SSH_KEY_PATH}"

# Test SSH connection
print_status "Testing SSH connection to Swarm master..."
ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@${SWARM_MASTER_IP} "echo 'Connection successful'" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    print_error "Cannot connect to Swarm master via SSH"
    print_warning "Please check:"
    print_warning "  - SSH key permissions: chmod 600 ${SSH_KEY_PATH}"
    print_warning "  - Security group allows SSH from your IP"
    print_warning "  - Master instance is running"
    exit 1
fi

print_success "SSH connection to Swarm master successful"

# Create deployment script
DEPLOY_SCRIPT="/tmp/deploy-${SERVICE_NAME}-$(date +%s).sh"
cat > "$DEPLOY_SCRIPT" << EOF
#!/bin/bash
set -e

echo "=== Docker Swarm Service Deployment ==="
echo "Service: ${SERVICE_NAME}"
echo "Image: ${FULL_IMAGE_NAME}"
echo "Port: ${PORT}"
echo "Replicas: ${REPLICAS}"
echo ""

# Login to ECR on the master node
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Check if service already exists
if docker service ls --format "table {{.Name}}" | grep -q "^${SERVICE_NAME}$"; then
    echo "Service ${SERVICE_NAME} exists. Updating..."
    docker service update \\
        --image ${FULL_IMAGE_NAME} \\
        --replicas ${REPLICAS} \\
        ${SERVICE_NAME}
else
    echo "Creating new service ${SERVICE_NAME}..."
    docker service create \\
        --name ${SERVICE_NAME} \\
        --replicas ${REPLICAS} \\
        --publish published=${PORT},target=\$(docker inspect ${FULL_IMAGE_NAME} --format='{{range \$p, \$conf := .Config.ExposedPorts}}{{\$p}}{{end}}' | cut -d/ -f1) \\
        --restart-condition on-failure \\
        --restart-max-attempts 3 \\
        --update-parallelism 1 \\
        --update-delay 10s \\
        --rollback-parallelism 1 \\
        --constraint 'node.role==worker' \\
        ${FULL_IMAGE_NAME}
fi

echo ""
echo "=== Deployment Status ==="
docker service ls
echo ""
echo "=== Service Details ==="
docker service ps ${SERVICE_NAME}
echo ""
echo "=== Service Logs (last 10 lines) ==="
docker service logs --tail 10 ${SERVICE_NAME} || echo "No logs available yet"
echo ""
echo "✅ Deployment completed successfully!"
echo "🌐 Service available at: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):${PORT}"
EOF

# Copy and execute deployment script
print_status "Copying deployment script to Swarm master..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$DEPLOY_SCRIPT" ec2-user@${SWARM_MASTER_IP}:/tmp/

print_status "Executing deployment on Swarm master..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@${SWARM_MASTER_IP} "chmod +x /tmp/$(basename $DEPLOY_SCRIPT) && /tmp/$(basename $DEPLOY_SCRIPT)"

if [ $? -eq 0 ]; then
    print_success "🎉 Deployment completed successfully!"
    
    # Get load balancer URL if available
    print_status "Getting load balancer information..."
    cd ../docker-swarm 2>/dev/null
    LOAD_BALANCER_URL=$(terraform output -raw load_balancer_url 2>/dev/null)
    cd - > /dev/null
    
    echo ""
    echo "📋 Deployment Summary:"
    echo "  Service Name: ${SERVICE_NAME}"
    echo "  Image: ${FULL_IMAGE_NAME}"
    echo "  Port: ${PORT}"
    echo "  Replicas: ${REPLICAS}"
    echo "  Swarm Master: ${SWARM_MASTER_IP}"
    if [ -n "$LOAD_BALANCER_URL" ]; then
        echo "  Load Balancer: ${LOAD_BALANCER_URL}"
    fi
    echo ""
    echo "🔍 Monitoring Commands:"
    echo "  Service status: ssh -i ${SSH_KEY_PATH} ec2-user@${SWARM_MASTER_IP} 'docker service ls'"
    echo "  Service tasks:  ssh -i ${SSH_KEY_PATH} ec2-user@${SWARM_MASTER_IP} 'docker service ps ${SERVICE_NAME}'"
    echo "  Service logs:   ssh -i ${SSH_KEY_PATH} ec2-user@${SWARM_MASTER_IP} 'docker service logs ${SERVICE_NAME}'"
    echo "  Scale service:  ssh -i ${SSH_KEY_PATH} ec2-user@${SWARM_MASTER_IP} 'docker service scale ${SERVICE_NAME}=<new-replicas>'"
    
else
    print_error "Deployment failed"
    exit 1
fi

# Clean up
rm -f "$DEPLOY_SCRIPT"

print_success "🎉 Service ${SERVICE_NAME} is now running on Docker Swarm!"