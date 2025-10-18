#!/bin/bash
source .env
set -e

echo "🚀 Starting Full Infrastructure Deployment..."

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

# Step 1: Deploy Bootstrap Infrastructure
print_status "Step 1/3: Deploying Bootstrap Infrastructure (S3 + DynamoDB)"
cd bootstrap
terraform init
terraform apply -auto-approve
if [ $? -eq 0 ]; then
    print_success "Bootstrap infrastructure deployed successfully"
else
    print_error "Bootstrap deployment failed"
    exit 1
fi
cd ..

# Step 2: Deploy VPC Infrastructure  
print_status "Step 2/3: Deploying VPC Infrastructure"
cd vpc
terraform init
terraform apply -auto-approve
if [ $? -eq 0 ]; then
    print_success "VPC infrastructure deployed successfully"
else
    print_error "VPC deployment failed"
    exit 1
fi
cd ..

# Step 3: Deploy Docker Swarm Infrastructure
print_status "Step 3/3: Deploying Docker Swarm Infrastructure"
cd docker-swarm
terraform init
terraform apply -auto-approve
if [ $? -eq 0 ]; then
    print_success "Docker Swarm infrastructure deployed successfully"
    
    # Get outputs for verification
    print_status "Getting deployment information..."
    LOAD_BALANCER_URL=$(terraform output -raw load_balancer_url)
    MASTER_IP=$(terraform output -raw swarm_master_public_ip)
    ECR_URL=$(terraform output -raw ecr_repository_url)
    
    print_success "Docker Swarm cluster ready!"
    echo "• Load Balancer URL: $LOAD_BALANCER_URL"
    echo "• Swarm Master IP: $MASTER_IP"
    echo "⏳ Worker nodes are joining automatically via SSM Parameter Store..."
    
    print_success "🎉 COMPLETE DEPLOYMENT FINISHED!"
    echo ""
    echo "📋 Infrastructure Summary:"
    echo "• Load Balancer URL: $LOAD_BALANCER_URL"
    echo "• Swarm Master IP: $MASTER_IP"
    echo "• ECR Repository: $ECR_URL"
    echo ""
    echo "� Next Steps:"
    echo "   1. SSH to master: ssh -i <your-private-key> ec2-user@$MASTER_IP"
    echo "   2. Deploy services manually or use deployment scripts"
    echo "   3. Check swarm status: sudo docker node ls"
    
else
    print_error "Docker Swarm deployment failed"
    exit 1
fi
cd ..

print_success "All infrastructure deployed successfully! 🎉"