#!/bin/bash
set -e

echo "🧹 Starting Complete Infrastructure Cleanup..."

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

# Function to force scale down ASG before destroying
force_scale_down_asg() {
    local asg_name=$1
    if [ -n "$asg_name" ]; then
        print_status "Scaling down Auto Scaling Group: $asg_name"
        aws autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$asg_name" \
            --min-size 0 \
            --max-size 0 \
            --desired-capacity 0 2>/dev/null || true
        
        print_status "Detaching instances from target groups..."
        aws autoscaling detach-load-balancer-target-groups \
            --auto-scaling-group-name "$asg_name" \
            --target-group-arns $(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'docker-swarm')].TargetGroupArn" --output text) 2>/dev/null || true
        
        print_status "Suspending ASG processes..."
        aws autoscaling suspend-processes --auto-scaling-group-name "$asg_name" 2>/dev/null || true
        
        print_status "Terminating instances in ASG..."
        local instance_ids=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$asg_name" \
            --query "AutoScalingGroups[0].Instances[*].InstanceId" \
            --output text 2>/dev/null)
        
        if [ -n "$instance_ids" ]; then
            for instance_id in $instance_ids; do
                print_status "Terminating instance: $instance_id"
                aws ec2 terminate-instances --instance-ids $instance_id 2>/dev/null || true
            done
        fi
    fi
}

# Function to safely destroy with retries
safe_destroy() {
    local dir=$1
    local name=$2
    local max_attempts=3
    local attempt=1
    
    print_status "Destroying $name (attempt $attempt/$max_attempts)"
    cd $dir
    
    # Special handling for Docker Swarm (has ASG and ALB)
    if [ "$name" == "Docker Swarm Infrastructure" ]; then
        print_status "Pre-cleanup: Scaling down Auto Scaling Group..."
        local asg_name=$(terraform output -raw autoscaling_group_name 2>/dev/null || echo "")
        force_scale_down_asg "$asg_name"
        
        print_status "Pre-cleanup: Destroying ASG and related resources first..."
        terraform destroy -target=module.ec2.aws_autoscaling_group.swarm_workers \
                         -target=module.ec2.aws_autoscaling_policy.scale_up \
                         -target=module.ec2.aws_autoscaling_policy.scale_down \
                         -target=module.ec2.aws_cloudwatch_metric_alarm.cpu_high \
                         -target=module.ec2.aws_cloudwatch_metric_alarm.cpu_low \
                         -auto-approve 2>/dev/null || true
    fi
    
    while [ $attempt -le $max_attempts ]; do
        if terraform destroy -auto-approve; then
            print_success "$name destroyed successfully"
            cd ..
            return 0
        else
            print_warning "$name destroy attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                print_status "Retrying immediately..."
                attempt=$((attempt + 1))
                
                # Try to scale down ASG again on retry for Docker Swarm
                if [ "$name" == "Docker Swarm Infrastructure" ]; then
                    local asg_name=$(terraform output -raw autoscaling_group_name 2>/dev/null || echo "")
                    force_scale_down_asg "$asg_name"
                fi
            else
                print_error "$name destroy failed after $max_attempts attempts"
                cd ..
                return 1
            fi
        fi
    done
}

# Step 1: Destroy Service Deployments
print_status "Step 1/4: Destroying Service Deployments"
if safe_destroy "service-deployment" "Service Deployments"; then
    print_success "Service deployments cleanup completed"
else
    print_warning "Service deployments cleanup failed - continuing with Docker Swarm"
fi

# Step 2: Destroy Docker Swarm Infrastructure
print_status "Step 2/4: Destroying Docker Swarm Infrastructure"
if safe_destroy "docker-swarm" "Docker Swarm Infrastructure"; then
    print_success "Docker Swarm cleanup completed"
else
    print_error "Docker Swarm cleanup failed - continuing with other resources"
fi

# Step 3: Destroy VPC Infrastructure
print_status "Step 3/4: Destroying VPC Infrastructure"
if safe_destroy "vpc" "VPC Infrastructure"; then
    print_success "VPC cleanup completed"
else
    print_error "VPC cleanup failed - continuing with bootstrap"
fi

# Step 4: Destroy Bootstrap Infrastructure
print_status "Step 4/4: Destroying Bootstrap Infrastructure"
if safe_destroy "bootstrap" "Bootstrap Infrastructure"; then
    print_success "Bootstrap cleanup completed"
else
    print_error "Bootstrap cleanup failed"
    exit 1
fi

print_success "🎉 Complete infrastructure cleanup finished!"
print_status "All AWS resources have been destroyed"
print_warning "State files and local .terraform directories may still exist"