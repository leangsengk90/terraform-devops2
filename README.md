# Infrastructure as Code (IaC) - Docker Swarm on AWS

**Project**: Production-Ready Docker Swarm Cluster on AWS  
**Technology**: Terraform, AWS, Docker Swarm  
**Author**: Kao Leangseng  
**Date**: October 2025

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Prerequisites](#prerequisites)
5. [Deployment Guide](#deployment-guide)
6. [Service Management](#service-management)
7. [Infrastructure Components](#infrastructure-components)
8. [Cost Optimization](#cost-optimization)
9. [Maintenance & Operations](#maintenance--operations)
10. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This Infrastructure as Code (IaC) project provisions a complete, production-ready Docker Swarm cluster on AWS using Terraform. The infrastructure is designed for high availability, scalability, and cost-effectiveness, leveraging AWS Free Tier eligible resources where possible.

### Key Features

✅ **Automated Deployment**: Complete infrastructure provisioning with single command  
✅ **High Availability**: Multi-AZ deployment with auto-scaling  
✅ **Modular Design**: Reusable Terraform modules  
✅ **State Management**: Remote state in S3 with DynamoDB locking  
✅ **Container Registry**: AWS ECR for Docker image storage  
✅ **Load Balancing**: Application Load Balancer with path-based routing  
✅ **Security**: VPC isolation, security groups, IAM roles  
✅ **Monitoring**: CloudWatch integration and auto-scaling metrics  
✅ **Service Deployment**: Automated service deployment to Swarm cluster  

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (Region: ap-southeast-1)      │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                         VPC (10.0.0.0/16)                 │ │
│  │                                                           │ │
│  │  ┌──────────────────┐         ┌──────────────────┐      │ │
│  │  │  Public Subnet   │         │  Public Subnet   │      │ │
│  │  │  (AZ-1a)         │         │  (AZ-1b)         │      │ │
│  │  │                  │         │                  │      │ │
│  │  │  ┌────────────┐  │         │  ┌────────────┐  │      │ │
│  │  │  │   Master   │  │         │  │  Worker-1  │  │      │ │
│  │  │  │  (t2.micro)│  │         │  │ (t2.micro) │  │      │ │
│  │  │  └────────────┘  │         │  └────────────┘  │      │ │
│  │  │                  │         │                  │      │ │
│  │  │                  │         │  ┌────────────┐  │      │ │
│  │  │                  │         │  │  Worker-2  │  │      │ │
│  │  │                  │         │  │ (t2.micro) │  │      │ │
│  │  │                  │         │  └────────────┘  │      │ │
│  │  └──────────────────┘         └──────────────────┘      │ │
│  │                                                           │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │     Application Load Balancer (ALB)                 │ │ │
│  │  │  - HTTP/HTTPS (80/443)                              │ │ │
│  │  │  - Path-based routing                               │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                External Services                          │ │
│  │  - ECR (Container Registry)                               │ │
│  │  - CloudWatch (Monitoring & Logging)                      │ │
│  │  - Systems Manager (Parameter Store)                     │ │
│  │  - S3 (Terraform State)                                   │ │
│  │  - DynamoDB (State Locking)                               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

| Component | Type | Count | Purpose |
|-----------|------|-------|---------|
| VPC | Network | 1 | Network isolation |
| Public Subnets | Network | 2 | Multi-AZ deployment |
| Internet Gateway | Network | 1 | Internet connectivity |
| Route Tables | Network | 2 | Traffic routing |
| Master Node | EC2 (t2.micro) | 1 | Swarm manager |
| Worker Nodes | EC2 (t2.micro) | 2-3 | Application containers |
| Auto Scaling Group | ASG | 1 | Worker auto-scaling |
| Load Balancer | ALB | 1 | Traffic distribution |
| Target Groups | ALB | 2+ | Service routing |
| Security Groups | VPC | 3 | Network security |
| IAM Roles | IAM | 1 | EC2 permissions |
| ECR Repository | ECR | 1+ | Container images |
| S3 Bucket | S3 | 1 | Terraform state |
| DynamoDB Table | DynamoDB | 1 | State locking |

---

## 📁 Project Structure

```
iac/
├── README.md                    # This file
├── .env                         # AWS credentials (gitignored)
├── deploy-all.sh               # Full deployment script
├── cleanup-all.sh              # Full cleanup script
│
├── bootstrap/                   # S3 & DynamoDB for state management
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│
├── vpc/                        # VPC infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│
├── docker-swarm/               # Docker Swarm cluster
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars        # Configuration values
│   ├── terraform.tfvars.example
│   ├── README.md
│   └── modules/
│       ├── alb/                # Application Load Balancer
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── ec2/                # EC2 instances & ASG
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── user_data/
│       │       ├── master.sh   # Master node initialization
│       │       └── worker.sh   # Worker node initialization
│       ├── ecr/                # Container registry
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/                # IAM roles & policies
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── security/           # Security groups
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── service-deployment/         # Service deployment automation
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── provider.tf
    ├── docker-compose.yml      # Nginx service (port 8080)
    └── docker-compose-nginx2.yml  # Nginx2 service (port 8081)
```

---

## 📦 Prerequisites

### Required Tools

1. **Terraform** (>= 1.0)
   ```bash
   brew install terraform  # macOS
   ```

2. **AWS CLI** (>= 2.0)
   ```bash
   brew install awscli  # macOS
   ```

3. **Docker** (optional, for local testing)
   ```bash
   brew install docker  # macOS
   ```

### AWS Requirements

1. **AWS Account** with Administrator access
2. **AWS Credentials** configured
   ```bash
   aws configure
   # OR
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   export AWS_DEFAULT_REGION="ap-southeast-1"
   ```

3. **SSH Key Pair** for EC2 access
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/docker-swarm-key
   ```

### AWS Free Tier Eligibility

- **750 hours/month** of t2.micro EC2 instances (12 months)
- **5 GB** of S3 storage
- **25 GB** of DynamoDB storage
- **1 GB** of ECR storage (always free)
- **10 GB** of data transfer out (12 months)

---

## 🚀 Deployment Guide

### Step 1: Clone and Configure

```bash
# Navigate to project directory
cd /Users/kao.leangseng/test/terraform/iac

# Configure AWS credentials in .env file
cat > .env << EOF
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="ap-southeast-1"
EOF

# Load credentials
source .env
```

### Step 2: Configure Docker Swarm

```bash
cd docker-swarm

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Key configurations to update:**
- `public_key`: Your SSH public key content
- `allowed_ssh_cidrs`: Your IP address for SSH access
- `worker_desired_capacity`: Number of worker nodes (default: 2)

### Step 3: Deploy Infrastructure

#### Option A: Automated Full Deployment (Recommended)

```bash
cd /Users/kao.leangseng/test/terraform/iac
./deploy-all.sh
```

This script will:
1. Deploy bootstrap infrastructure (S3 + DynamoDB)
2. Deploy VPC infrastructure
3. Deploy Docker Swarm cluster
4. Display deployment summary

#### Option B: Manual Step-by-Step Deployment

```bash
# 1. Deploy Bootstrap
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..

# 2. Deploy VPC
cd vpc
terraform init
terraform apply -auto-approve
cd ..

# 3. Deploy Docker Swarm
cd docker-swarm
terraform init
terraform apply -auto-approve
cd ..
```

### Step 4: Verify Deployment

```bash
cd docker-swarm

# Get deployment outputs
terraform output

# Expected outputs:
# - load_balancer_url: http://docker-swarm-alb-xxxxx.ap-southeast-1.elb.amazonaws.com
# - swarm_master_public_ip: x.x.x.x
# - ecr_repository_url: xxxxx.dkr.ecr.ap-southeast-1.amazonaws.com/docker-swarm-app
```

### Step 5: Access Docker Swarm Cluster

```bash
# SSH to master node
ssh -i ~/.ssh/docker-swarm-key ec2-user@<master-ip>

# Verify cluster
sudo docker node ls

# Expected output:
# ID                  HOSTNAME            STATUS    AVAILABILITY    MANAGER STATUS
# xxxxx *             ip-10-0-x-x         Ready     Active          Leader
# xxxxx               ip-10-0-x-x         Ready     Active
# xxxxx               ip-10-0-x-x         Ready     Active
```

---

## 🐳 Service Management

### Deploy Services Using Terraform

The `service-deployment` module allows you to deploy Docker services to your Swarm cluster automatically.

#### Deploy Nginx Services

```bash
cd service-deployment

# Initialize Terraform
terraform init

# Deploy services (nginx on port 8080, nginx2 on port 8081)
terraform apply -auto-approve
```

#### Add More Services

Edit `service-deployment/variables.tf`:

```hcl
variable "services" {
  default = [
    {
      compose_file = "docker-compose.yml"
      stack_name   = "nginx-stack"
    },
    {
      compose_file = "docker-compose-nginx2.yml"
      stack_name   = "nginx2-stack"
    },
    {
      compose_file = "docker-compose-myapp.yml"
      stack_name   = "myapp-stack"
    }
  ]
}
```

Create `docker-compose-myapp.yml`:

```yaml
version: "3.8"

services:
  myapp:
    image: myapp:latest
    ports:
      - "8082:80"
    deploy:
      mode: replicated
      replicas: 2
      placement:
        constraints:
          - node.role == worker
      restart_policy:
        condition: on-failure
    networks:
      - webnet

networks:
  webnet:
    driver: overlay
```

Then apply:

```bash
terraform apply -auto-approve
```

### Manual Service Deployment

#### Push Image to ECR

```bash
# Get ECR login
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com

# Tag image
docker tag my-app:latest <ecr-url>:latest

# Push to ECR
docker push <ecr-url>:latest
```

#### Deploy to Swarm (SSH to Master)

```bash
# SSH to master
ssh -i ~/.ssh/docker-swarm-key ec2-user@<master-ip>

# Create service
sudo docker service create \
  --name web \
  --replicas 3 \
  --publish 8080:80 \
  <ecr-url>:latest

# Verify service
sudo docker service ls
sudo docker service ps web
```

#### Update Service

```bash
# Update image
sudo docker service update --image <ecr-url>:v2 web

# Scale service
sudo docker service scale web=5
```

#### Remove Service

```bash
sudo docker service rm web
```

---

## 🔧 Infrastructure Components

### 1. Bootstrap Module

**Purpose**: Terraform state management  
**Resources**:
- S3 bucket for state storage
- DynamoDB table for state locking

**Location**: `bootstrap/`

### 2. VPC Module

**Purpose**: Network infrastructure  
**Resources**:
- VPC (10.0.0.0/16)
- 2 Public subnets (Multi-AZ)
- Internet Gateway
- Route tables

**Location**: `vpc/`

### 3. Docker Swarm Module

**Purpose**: Container orchestration cluster  
**Location**: `docker-swarm/`

#### Sub-Modules:

**a) EC2 Module** (`modules/ec2/`)
- 1 Master node (t2.micro)
- Auto Scaling Group for workers (2-3 nodes)
- Launch templates
- User data scripts for automated setup
- CloudWatch alarms for auto-scaling

**b) ALB Module** (`modules/alb/`)
- Application Load Balancer
- HTTP listener (port 80)
- Target groups for services
- Path-based routing rules
- Health checks

**c) Security Module** (`modules/security/`)
- ALB security group (ports 80, 443)
- Master security group (SSH, Swarm ports)
- Worker security group (Swarm ports, app ports)

**d) IAM Module** (`modules/iam/`)
- EC2 instance role
- ECR access policy
- CloudWatch logs policy
- Systems Manager policy

**e) ECR Module** (`modules/ecr/`)
- Docker image repository
- Lifecycle policies
- Image scanning

### 4. Service Deployment Module

**Purpose**: Automated service deployment  
**Resources**:
- null_resource for file provisioning
- SSH-based deployment
- Multi-service support

**Location**: `service-deployment/`

---

## 💰 Cost Optimization

### AWS Free Tier Usage

This infrastructure is optimized for AWS Free Tier:

| Resource | Free Tier | Monthly Usage | Cost |
|----------|-----------|---------------|------|
| EC2 (t2.micro) | 750 hours/month | ~2160 hours (3 instances × 720h) | Exceeds free tier* |
| S3 Storage | 5 GB | < 1 GB | FREE |
| DynamoDB | 25 GB | < 1 GB | FREE |
| ECR | 1 GB | < 500 MB | FREE |
| Data Transfer | 10 GB out | < 5 GB | FREE |
| ALB | Not free | 1 ALB | ~$16/month |

**Important Notes**:
1. Free tier covers **750 hours total**, not per instance
2. With 3 instances (1 master + 2 workers) running 24/7:
   - Total hours: 3 × 720 = 2,160 hours/month
   - Free hours: 750 hours/month
   - **Billable hours: 1,410 hours/month**
   - **Estimated cost: ~$10-15/month for EC2**

3. ALB is **not** covered by free tier: ~$16/month

**Total Estimated Cost**: ~$26-31/month

### Cost Reduction Strategies

1. **Reduce Worker Count**:
   ```hcl
   worker_desired_capacity = 1  # Instead of 2
   worker_min_size        = 1
   ```
   Saves ~$7/month

2. **Use Scheduled Scaling**:
   - Scale down workers during non-business hours
   - Implement using AWS Auto Scaling schedules

3. **Remove ALB** (Not recommended for production):
   - Direct access to instances
   - Saves $16/month

4. **Use Spot Instances** for workers:
   - 70-90% cost reduction
   - Suitable for fault-tolerant workloads

---

## 🔧 Maintenance & Operations

### Monitoring

#### CloudWatch Metrics

```bash
# View CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=docker-swarm-swarm-workers \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

#### Service Health

```bash
# SSH to master
ssh -i ~/.ssh/docker-swarm-key ec2-user@<master-ip>

# Check node status
sudo docker node ls

# Check service status
sudo docker service ls

# View service logs
sudo docker service logs <service-name>
```

### Scaling

#### Manual Scaling

```bash
# Scale workers (via AWS Console or CLI)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name docker-swarm-swarm-workers \
  --desired-capacity 3

# Scale service replicas
ssh -i ~/.ssh/docker-swarm-key ec2-user@<master-ip>
sudo docker service scale web=5
```

#### Auto Scaling

Auto-scaling is configured automatically:
- **Scale Up**: CPU > 70% for 2 minutes
- **Scale Down**: CPU < 30% for 2 minutes
- **Min Workers**: 2
- **Max Workers**: 3

### Backup & Recovery

#### State Backup

```bash
# Terraform state is automatically backed up to S3
# Manual backup:
cd docker-swarm
terraform state pull > backup-$(date +%Y%m%d).tfstate
```

#### ECR Image Backup

```bash
# Pull all images
docker pull <ecr-url>:tag

# Save to tar
docker save <ecr-url>:tag > backup.tar

# Restore
docker load < backup.tar
```

### Updates & Upgrades

#### Update Infrastructure

```bash
cd docker-swarm

# Review changes
terraform plan

# Apply updates
terraform apply
```

#### Update Docker Swarm

```bash
# SSH to master
ssh -i ~/.ssh/docker-swarm-key ec2-user@<master-ip>

# Update Docker
sudo yum update docker -y
sudo systemctl restart docker
```

---

## 🧹 Cleanup

### Automated Full Cleanup

```bash
cd /Users/kao.leangseng/test/terraform/iac
./cleanup-all.sh
```

This script will:
1. Destroy service deployments
2. Destroy Docker Swarm infrastructure
3. Destroy VPC infrastructure
4. Destroy bootstrap infrastructure

### Manual Cleanup

```bash
# 1. Destroy Service Deployments
cd service-deployment
terraform destroy -auto-approve
cd ..

# 2. Destroy Docker Swarm
cd docker-swarm
terraform destroy -auto-approve
cd ..

# 3. Destroy VPC
cd vpc
terraform destroy -auto-approve
cd ..

# 4. Destroy Bootstrap
cd bootstrap
terraform destroy -auto-approve
cd ..
```

### Verify Cleanup

```bash
# Check EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,Tags[?Key==`Project`].Value]'

# Check Load Balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `docker-swarm`)].[LoadBalancerName,DNSName]'

# Check S3 buckets
aws s3 ls | grep devops-group4
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Terraform State Lock

**Error**: `Error acquiring the state lock`

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

#### 2. Worker Nodes Not Joining

**Symptoms**: Workers not appearing in `docker node ls`

**Solution**:
```bash
# SSH to master
ssh -i ~/.ssh/docker-swarm-key ec2-user@<master-ip>

# Check SSM parameters
aws ssm get-parameter --name /docker-swarm/worker-token --with-decryption

# Check worker logs
ssh -i ~/.ssh/docker-swarm-key ec2-user@<worker-ip>
sudo cat /var/log/cloud-init-output.log
```

#### 3. ALB Health Checks Failing

**Symptoms**: Targets unhealthy in ALB

**Solution**:
```bash
# Check security groups
aws ec2 describe-security-groups --group-ids <worker-sg-id>

# Verify service is running
ssh -i ~/.ssh/docker-swarm-key ec2-user@<worker-ip>
sudo docker service ls
curl localhost:8080
```

#### 4. ECR Access Denied

**Error**: `no basic auth credentials`

**Solution**:
```bash
# Re-authenticate
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin <ecr-url>
```

#### 5. Auto Scaling Group Stuck on Destroy

**Symptoms**: Cleanup hangs on ASG deletion

**Solution**:
```bash
# Force terminate instances
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name docker-swarm-swarm-workers \
  --min-size 0 --max-size 0 --desired-capacity 0

# Wait and retry
terraform destroy -auto-approve
```

### Getting Help

1. **Check Terraform Logs**:
   ```bash
   TF_LOG=DEBUG terraform apply
   ```

2. **AWS CloudWatch Logs**:
   - Navigate to CloudWatch > Log Groups
   - Check `/aws/ec2/docker-swarm/master` and `/aws/ec2/docker-swarm/worker`

3. **AWS Console**:
   - EC2 Dashboard for instance status
   - Auto Scaling Groups for scaling events
   - Load Balancers for target health

---

## 📚 Additional Resources

### Documentation

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)

### Best Practices

1. **Version Control**: Always commit Terraform code to Git
2. **State Management**: Use remote state with locking
3. **Secrets**: Never commit credentials; use environment variables
4. **Tagging**: Consistent resource tagging for cost tracking
5. **Backup**: Regular backups of Terraform state and application data

---

## 📝 License

This project is for educational and demonstration purposes.

---

## 👤 Author

**Kao Leangseng**  
DevOps Engineer  
October 2025

---

## 🙏 Acknowledgments

- AWS for Free Tier offerings
- HashiCorp for Terraform
- Docker for Swarm orchestration

---

**Last Updated**: October 17, 2025
