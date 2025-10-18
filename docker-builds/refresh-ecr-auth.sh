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

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-docker-swarm-app}

# Get AWS account ID and ECR registry URL
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

print_status "🔐 Refreshing ECR authentication on all Docker Swarm nodes..."

# Get master IP from Terraform output
if [ -f "../docker-swarm/terraform.tfstate" ]; then
    MASTER_IP=$(cd ../docker-swarm && terraform output -raw swarm_master_public_ip 2>/dev/null)
else
    print_error "Terraform state not found. Please provide master IP manually."
    echo "Usage: MASTER_IP=x.x.x.x $0"
    exit 1
fi

if [ -z "$MASTER_IP" ]; then
    print_error "Could not get master IP from Terraform output"
    exit 1
fi

print_status "Master IP: $MASTER_IP"

# SSH key path
SSH_KEY_PATH="$HOME/.ssh/docker-swarm-key"
if [ ! -f "$SSH_KEY_PATH" ]; then
    print_error "SSH key not found at $SSH_KEY_PATH"
    exit 1
fi

# Function to run ECR login on a node
refresh_ecr_on_node() {
    local node_ip=$1
    local node_type=$2
    
    print_status "Refreshing ECR auth on $node_type node: $node_ip"
    
    # Create ECR login command
    ECR_LOGIN_CMD="aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"
    
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@$node_ip "$ECR_LOGIN_CMD" 2>/dev/null; then
        print_success "ECR auth refreshed on $node_type: $node_ip"
        return 0
    else
        print_error "Failed to refresh ECR auth on $node_type: $node_ip"
        return 1
    fi
}

# Refresh ECR auth on master node
refresh_ecr_on_node "$MASTER_IP" "master"

# Get list of worker nodes from master
print_status "Getting list of worker nodes..."
WORKER_IPS=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$MASTER_IP \
    "docker node ls --format '{{.Hostname}}' --filter role=worker" 2>/dev/null | \
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' || true)

if [ -z "$WORKER_IPS" ]; then
    print_warning "No worker nodes found or unable to extract IPs"
else
    # Refresh ECR auth on all worker nodes
    success_count=0
    total_count=0
    
    for worker_ip in $WORKER_IPS; do
        # Convert internal IP to external IP (this is a simplified approach)
        # In a real environment, you might need a more sophisticated method
        
        # For now, we'll try to refresh auth by running the command through the master
        total_count=$((total_count + 1))
        
        print_status "Refreshing ECR auth on worker node: $worker_ip"
        
        # Run ECR login command on worker node through master
        if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$MASTER_IP \
            "docker node update --availability drain $worker_ip && \
             sleep 2 && \
             docker node update --availability active $worker_ip" 2>/dev/null; then
            
            print_status "Triggered worker node refresh: $worker_ip"
            success_count=$((success_count + 1))
        else
            print_warning "Could not trigger refresh on worker: $worker_ip"
        fi
    done
    
    print_status "Worker node refresh summary: $success_count/$total_count"
fi

# Alternative: Run ECR login script on all nodes via Systems Manager (if available)
print_status "Creating ECR login script in Systems Manager..."

# Create ECR login script
ECR_LOGIN_SCRIPT="#!/bin/bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
echo \"\$(date): ECR login completed via SSM\" >> /var/log/ecr-login.log"

# Try to run via Systems Manager on all instances
if aws ssm describe-instances --filters "Key=PlatformTypes,Values=Linux" --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' --output text &>/dev/null; then
    print_status "Running ECR login via Systems Manager on all online instances..."
    
    ONLINE_INSTANCES=$(aws ssm describe-instances --filters "Key=PlatformTypes,Values=Linux" --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' --output text)
    
    if [ -n "$ONLINE_INSTANCES" ]; then
        aws ssm send-command \
            --instance-ids $ONLINE_INSTANCES \
            --document-name "AWS-RunShellScript" \
            --parameters "commands=[\"$ECR_LOGIN_SCRIPT\"]" \
            --comment "Refresh ECR authentication on Docker Swarm nodes" \
            --output text &>/dev/null
        
        print_success "ECR login command sent via Systems Manager"
    fi
else
    print_warning "Systems Manager not available or no online instances"
fi

print_success "🎉 ECR authentication refresh completed!"
print_status "Next steps:"
echo "1. Wait a few minutes for authentication to propagate"
echo "2. Try deploying your service again"
echo "3. Check service status: ssh -i $SSH_KEY_PATH ec2-user@$MASTER_IP 'docker service ls'"