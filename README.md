# Infrastructure as Code (IaC) - Docker Swarm on AWS

**Project**: Production-Ready Docker Swarm Cluster on AWS with Automated Container Deployment  
**Technology**: Terraform, AWS, Docker Swarm, ECR, CI/CD  
**Author**: Kao Leangseng  
**Date**: October 2025  
**Version**: 2.0

---

## 📋 Table of Contents

1. [Overview](#-overview)
2. [Architecture](#-architecture)
3. [Project Structure](#-project-structure)
4. [Prerequisites](#-prerequisites)
5. [Quick Start](#-quick-start)
6. [Deployment Guide](#-deployment-guide)
7. [Container Management](#-container-management)
8. [Service Management](#-service-management)
9. [Infrastructure Components](#-infrastructure-components)
10. [Docker Builds System](#-docker-builds-system)
11. [ECR Authentication](#-ecr-authentication)
12. [Cost Optimization](#-cost-optimization)
13. [Maintenance & Operations](#-maintenance--operations)
14. [Troubleshooting](#-troubleshooting)
15. [Documentation](#-documentation)

---

## 🎯 Overview

This Infrastructure as Code (IaC) project provisions a complete, production-ready Docker Swarm cluster on AWS using Terraform. The infrastructure includes automated Docker image building, ECR management, and container deployment workflows designed for high availability, scalability, and cost-effectiveness.

### ✨ Key Features

🚀 **Complete Infrastructure Automation**

- Full infrastructure provisioning with single command
- Multi-AZ deployment with auto-scaling worker nodes
- Automated ECR authentication and token refresh

🐳 **Container Management System**

- Docker image building and ECR pushing automation
- Sample applications (Node.js, Python Flask, Custom Nginx)
- Local development environment with Docker Compose
- Automated service deployment to Docker Swarm

🔒 **Production-Ready Security**

- VPC isolation with public/private subnets
- Security groups with least privilege access
- IAM roles with ECR and CloudWatch permissions
- Automated ECR authentication refresh (every 6 hours)

📊 **Scalability & Monitoring**

- Application Load Balancer with path-based routing
- Auto-scaling worker nodes based on CPU metrics
- CloudWatch integration for monitoring and logging
- Health checks and rolling updates

🏗️ **Infrastructure as Code**

- Modular Terraform design for reusability
- Remote state management with S3 and DynamoDB locking
- Comprehensive documentation and troubleshooting guides
- 67-page technical documentation included

### 🎯 Use Cases

- **Development Teams**: Local development with production-like environment
- **DevOps Learning**: Complete CI/CD pipeline with container orchestration
- **Microservices**: Multi-service deployment with load balancing
- **Cost-Effective Production**: AWS Free Tier eligible configuration

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
│  │  ┌─────────── PUBLIC SUBNETS ─────────────┐               │ │
│  │  │                                       │               │ │
│  │  │  ┌──────────────────┐  ┌──────────────────┐         │ │
│  │  │  │  Public Subnet   │  │  Public Subnet   │         │ │
│  │  │  │ (10.0.1.0/24)    │  │ (10.0.2.0/24)    │         │ │
│  │  │  │    (AZ-1a)       │  │    (AZ-1b)       │         │ │
│  │  │  │                  │  │                  │         │ │
│  │  │  │  ┌────────────┐  │  │                  │         │ │
│  │  │  │  │   Master   │  │  │    ┌───────────┐ │         │ │
│  │  │  │  │  (t2.micro)│  │  │    │    NAT    │ │         │ │
│  │  │  │  │ SSH Access │  │  │    │  Gateway  │ │         │ │
│  │  │  │  └────────────┘  │  │    └───────────┘ │         │ │
│  │  │  └──────────────────┘  └──────────────────┘         │ │
│  │  └───────────────────────────────────────────────────────┘ │
│  │                                                           │ │
│  │  ┌─────────── PRIVATE SUBNETS ────────────┐               │ │
│  │  │                                       │               │ │
│  │  │  ┌──────────────────┐  ┌──────────────────┐         │ │
│  │  │  │ Private Subnet   │  │ Private Subnet   │         │ │
│  │  │  │ (10.0.10.0/24)   │  │ (10.0.20.0/24)   │         │ │
│  │  │  │    (AZ-1a)       │  │    (AZ-1b)       │         │ │
│  │  │  │                  │  │                  │         │ │
│  │  │  │  ┌────────────┐  │  │  ┌────────────┐  │         │ │
│  │  │  │  │  Worker-1  │  │  │  │  Worker-2  │  │         │ │
│  │  │  │  │ (t2.micro) │  │  │  │ (t2.micro) │  │         │ │
│  │  │  │  │Auto Scaling│  │  │  │Auto Scaling│  │         │ │
│  │  │  │  └────────────┘  │  │  └────────────┘  │         │ │
│  │  │  │        ▲         │  │        ▲         │         │ │
│  │  │  │        │         │  │        │         │         │ │
│  │  │  └────────┼─────────┘  └────────┼─────────┘         │ │
│  │  └───────────┼─────────────────────┼───────────────────┘ │
│  │              │                     │                     │ │
│  │  ┌───────────┼─────────────────────┼───────────────────┐ │ │
│  │  │           ▼                     ▼                   │ │ │
│  │  │     Application Load Balancer (ALB)                 │ │ │
│  │  │  - HTTP/HTTPS (80/443)                              │ │ │
│  │  │  - Path-based routing to private workers            │ │ │
│  │  │  - Health checks & failover                         │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  │                                                           │ │
│  │  ┌─── Internet Gateway ───┐   ┌── Route Tables ────────┐ │ │
│  │  │  - Public internet      │   │ Public: 0.0.0.0/0 →IGW│ │ │
│  │  │  - Bi-directional       │   │ Private: 0.0.0.0/0→NAT│ │ │
│  │  └─────────────────────────┘   └────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                External Services                          │ │
│  │  - ECR (Container Registry) - via NAT Gateway             │ │
│  │  - CloudWatch (Monitoring & Logging)                      │ │
│  │  - Systems Manager (Parameter Store)                     │ │
│  │  - S3 (Terraform State)                                   │ │
│  │  - DynamoDB (State Locking)                               │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

| Component          | Type           | Count | Purpose                |
| ------------------ | -------------- | ----- | ---------------------- |
| VPC                | Network        | 1     | Network isolation      |
| Public Subnets     | Network        | 2     | Multi-AZ deployment    |
| Internet Gateway   | Network        | 1     | Internet connectivity  |
| Route Tables       | Network        | 2     | Traffic routing        |
| Master Node        | EC2 (t2.micro) | 1     | Swarm manager          |
| Worker Nodes       | EC2 (t2.micro) | 2-3   | Application containers |
| Auto Scaling Group | ASG            | 1     | Worker auto-scaling    |
| Load Balancer      | ALB            | 1     | Traffic distribution   |
| Target Groups      | ALB            | 2+    | Service routing        |
| Security Groups    | VPC            | 3     | Network security       |
| IAM Roles          | IAM            | 1     | EC2 permissions        |
| ECR Repository     | ECR            | 1+    | Container images       |
| S3 Bucket          | S3             | 1     | Terraform state        |
| DynamoDB Table     | DynamoDB       | 1     | State locking          |

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
├── docker-builds/              # 🆕 Docker Image Building System
│   ├── README.md               # Docker builds documentation
│   ├── EXAMPLES.md            # Usage examples and CI/CD
│   ├── ecr-login.sh           # ECR authentication
│   ├── build-and-push.sh      # Main build & push script
│   ├── deploy-to-swarm.sh     # Deploy to Docker Swarm
│   ├── refresh-ecr-auth.sh    # 🆕 Fix ECR auth on existing cluster
│   ├── setup.sh               # Environment setup
│   ├── test-local.sh          # Local testing with docker-compose
│   ├── docker-compose.yml     # Multi-service local environment
│   ├── nginx-lb.conf          # Load balancer configuration
│   ├── scripts/               # Automation scripts
│   │   ├── build-all.sh       # Build all applications
│   │   ├── build-single.sh    # Build individual app
│   │   └── cleanup-images.sh  # Clean up Docker images
│   └── sample-apps/           # Sample applications
│       ├── nodejs-app/        # Node.js Express application
│       │   ├── Dockerfile
│       │   ├── package.json
│       │   ├── app.js
│       │   └── README.md
│       ├── python-app/        # Python Flask application
│       │   ├── Dockerfile
│       │   ├── requirements.txt
│       │   ├── app.py
│       │   └── README.md
│       └── nginx-custom/      # Custom Nginx with static content
│           ├── Dockerfile
│           ├── nginx.conf
│           ├── index.html
│           └── README.md
│
├── service-deployment/         # Service deployment automation
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── docker-compose.yml      # Nginx service (port 8080)
│   └── docker-compose-nginx2.yml  # Nginx2 service (port 8081)
│
└── TECHNICAL_DOCUMENTATION.md  # 📚 67-page comprehensive guide
```

---

## ⚡ Quick Start

### 🚀 Full Infrastructure Deployment (5 minutes)

```bash
# 1. Clone and configure
cd iac/
cp .env.example .env
# Edit .env with your AWS credentials

# 2. Deploy everything
./deploy-all.sh

# 3. Access your cluster
# Load Balancer URL will be shown in output
```

### 🐳 Build and Deploy Sample Applications

```bash
# 1. Build sample applications
cd docker-builds/
./ecr-login.sh
./scripts/build-all.sh

# 2. Deploy to Docker Swarm
./deploy-to-swarm.sh nodejs-app latest 3000 2
./deploy-to-swarm.sh python-app latest 5000 2
./deploy-to-swarm.sh nginx-custom latest 80 2

# 3. Test locally (optional)
./test-local.sh
```

### 🔧 ECR Authentication Issues?

```bash
# If services can't pull images from ECR
cd docker-builds/
./refresh-ecr-auth.sh

# Or apply latest Terraform changes for auto-auth
cd ../docker-swarm/
terraform apply
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

## 🐳 Container Management

### Docker Builds System Overview

The `docker-builds/` directory provides a complete container image management system:

| Tool                   | Purpose                 | Usage                                           |
| ---------------------- | ----------------------- | ----------------------------------------------- |
| `ecr-login.sh`         | ECR authentication      | `./ecr-login.sh`                                |
| `build-and-push.sh`    | Build & push single app | `./build-and-push.sh nodejs-app latest`         |
| `scripts/build-all.sh` | Build & push all apps   | `./scripts/build-all.sh`                        |
| `deploy-to-swarm.sh`   | Deploy to cluster       | `./deploy-to-swarm.sh nodejs-app latest 3000 2` |
| `refresh-ecr-auth.sh`  | Fix ECR auth issues     | `./refresh-ecr-auth.sh`                         |
| `test-local.sh`        | Local testing           | `./test-local.sh`                               |

### Sample Applications

#### 1. Node.js Express Application (`nodejs-app`)

```bash
# Build and deploy
cd docker-builds/
./build-and-push.sh nodejs-app latest
./deploy-to-swarm.sh nodejs-app latest 3000 3

# Features:
# - Express web server on port 3000
# - Health check endpoint (/health)
# - Environment info display
# - Graceful shutdown handling
```

#### 2. Python Flask Application (`python-app`)

```bash
# Build and deploy
./build-and-push.sh python-app latest
./deploy-to-swarm.sh python-app latest 5000 2

# Features:
# - Flask web server on port 5000
# - REST API endpoints
# - Request logging
# - Docker health checks
```

#### 3. Custom Nginx (`nginx-custom`)

```bash
# Build and deploy
./build-and-push.sh nginx-custom latest
./deploy-to-swarm.sh nginx-custom latest 80 2

# Features:
# - Custom static content
# - Optimized Nginx configuration
# - Health monitoring
# - Load balancer ready
```

### Local Development Environment

```bash
# Test all services locally
cd docker-builds/
./test-local.sh

# Services available at:
# - http://localhost:3000 (Node.js app)
# - http://localhost:5000 (Python app)
# - http://localhost:8080 (Nginx with load balancing)
```

### Container Registry Management

```bash
# List ECR repositories
aws ecr describe-repositories --region ap-southeast-1

# List images in repository
aws ecr describe-images --repository-name docker-swarm-app

# Clean up old images locally
cd docker-builds/scripts/
./cleanup-images.sh
```

---

## 🛠️ Service Management

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

## 🐳 Docker Builds System

### Overview

The `docker-builds/` system provides comprehensive Docker image management:

```
docker-builds/
├── 🔐 Authentication
│   ├── ecr-login.sh           # ECR login automation
│   └── refresh-ecr-auth.sh    # Fix auth on existing clusters
├── 🏗️ Build & Deploy
│   ├── build-and-push.sh      # Single app build & push
│   ├── deploy-to-swarm.sh     # Deploy to Docker Swarm
│   └── scripts/
│       ├── build-all.sh       # Build all applications
│       ├── build-single.sh    # Build individual app
│       └── cleanup-images.sh  # Clean up local images
├── 🧪 Testing & Development
│   ├── test-local.sh          # Local multi-service testing
│   ├── docker-compose.yml     # Local development environment
│   └── nginx-lb.conf          # Load balancer config
└── 📦 Sample Applications
    ├── nodejs-app/            # Node.js Express (port 3000)
    ├── python-app/            # Python Flask (port 5000)
    └── nginx-custom/          # Custom Nginx (port 80)
```

### Key Features

🚀 **Automated ECR Management**

- Automatic ECR login and token refresh
- One-command build and push to ECR
- Support for multiple image tags

🐳 **Sample Applications Ready**

- Production-ready Node.js Express app
- Python Flask REST API
- Custom Nginx with optimized configuration

🔧 **Development Tools**

- Local multi-service testing environment
- Load balancer simulation with Nginx
- Health checks and monitoring endpoints

⚙️ **CI/CD Ready**

- GitHub Actions workflow examples
- Automated build and deployment scripts
- Environment-specific configurations

### Usage Examples

```bash
# Quick start - build and deploy all apps
cd docker-builds/
./ecr-login.sh
./scripts/build-all.sh

# Deploy specific service
./deploy-to-swarm.sh nodejs-app latest 3000 3

# Local development
./test-local.sh
# Access: http://localhost:8080 (load balanced)

# ECR authentication issues?
./refresh-ecr-auth.sh
```

### Integration with Infrastructure

| Component      | Integration Point           | Purpose             |
| -------------- | --------------------------- | ------------------- |
| ECR Repository | `docker-swarm/modules/ecr/` | Image storage       |
| IAM Roles      | `docker-swarm/modules/iam/` | ECR permissions     |
| ALB            | `docker-swarm/modules/alb/` | Load balancing      |
| Auto Scaling   | `docker-swarm/modules/ec2/` | Worker scaling      |
| User Data      | `user_data/master.sh`       | ECR auth automation |

---

## 🔐 ECR Authentication

### Automatic Authentication (Recommended)

**For New Deployments:**

```bash
# Latest user data includes automatic ECR auth
cd docker-swarm/
terraform apply
```

**Features:**

- Automatic ECR login on instance startup
- Periodic token refresh every 6 hours via cron
- All nodes (master + workers) stay authenticated

### Manual Authentication Fix

**For Existing Clusters:**

```bash
cd docker-builds/
./refresh-ecr-auth.sh
```

**This script will:**

1. SSH to master node
2. Refresh ECR authentication
3. Distribute tokens to all worker nodes
4. Verify authentication on all nodes

### Authentication Verification

```bash
# Check ECR authentication on master
ssh ec2-user@<master-ip> 'docker system info | grep Registry'

# Verify image pull capability
ssh ec2-user@<master-ip> 'docker pull 481604401489.dkr.ecr.ap-southeast-1.amazonaws.com/docker-swarm-app:latest'
```

### Troubleshooting ECR Issues

| Issue                  | Cause                  | Solution                       |
| ---------------------- | ---------------------- | ------------------------------ |
| `no such image`        | Authentication expired | `./refresh-ecr-auth.sh`        |
| `access denied`        | IAM permissions        | Check ECR policy in IAM module |
| `repository not found` | Wrong region/repo      | Verify ECR repository name     |
| `unauthorized`         | Token expired          | Re-run ECR login               |

---

## 💰 Cost Optimization

### AWS Free Tier Usage

This infrastructure is optimized for AWS Free Tier:

| Resource       | Free Tier       | Monthly Usage                    | Cost                |
| -------------- | --------------- | -------------------------------- | ------------------- |
| EC2 (t2.micro) | 750 hours/month | ~2160 hours (3 instances × 720h) | Exceeds free tier\* |
| S3 Storage     | 5 GB            | < 1 GB                           | FREE                |
| DynamoDB       | 25 GB           | < 1 GB                           | FREE                |
| ECR            | 1 GB            | < 500 MB                         | FREE                |
| Data Transfer  | 10 GB out       | < 5 GB                           | FREE                |
| ALB            | Not free        | 1 ALB                            | ~$16/month          |

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

## 📚 Documentation

### 📖 Project Documentation

| Document                                                       | Description                         | Size     |
| -------------------------------------------------------------- | ----------------------------------- | -------- |
| **[TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md)** | 📋 Complete 67-page technical guide | 67 pages |
| **[docker-builds/README.md](./docker-builds/README.md)**       | 🐳 Docker builds system guide       | 8 pages  |
| **[docker-builds/EXAMPLES.md](./docker-builds/EXAMPLES.md)**   | 💡 Usage examples & CI/CD patterns  | 12 pages |

### 📂 Application Documentation

| Application                                                            | Documentation      | Features                              |
| ---------------------------------------------------------------------- | ------------------ | ------------------------------------- |
| **[Node.js App](./docker-builds/sample-apps/nodejs-app/README.md)**    | Express web server | Health checks, graceful shutdown      |
| **[Python App](./docker-builds/sample-apps/python-app/README.md)**     | Flask REST API     | Request logging, health endpoints     |
| **[Nginx Custom](./docker-builds/sample-apps/nginx-custom/README.md)** | Static web server  | Load balancer ready, optimized config |

### 🌐 External Resources

**Infrastructure & Tools:**

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS Free Tier](https://aws.amazon.com/free/)

**Best Practices & Learning:**

- [12-Factor App Methodology](https://12factor.net/)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### 🛡️ Security & Compliance

**Infrastructure Security:**

1. **VPC Isolation**: Network segregation with public/private subnets
2. **Security Groups**: Least privilege network access
3. **IAM Roles**: Fine-grained permissions for EC2 and ECR
4. **State Management**: Encrypted S3 backend with DynamoDB locking

**Container Security:**

1. **Image Scanning**: ECR vulnerability scanning enabled
2. **Non-root Users**: Applications run as non-privileged users
3. **Health Checks**: Comprehensive application health monitoring
4. **Secret Management**: Environment-based configuration

**Operational Best Practices:**

1. **Version Control**: All infrastructure code in Git
2. **Immutable Infrastructure**: Infrastructure as Code approach
3. **Monitoring**: CloudWatch integration for all resources
4. **Backup Strategy**: Automated state backup and disaster recovery

---

## 📝 License

This project is for educational and demonstration purposes. Feel free to use and modify for learning and development.

---

## 👤 Author

**Kao Leangseng**  
DevOps Engineer  
October 2025

🔗 **Repository**: [terraform-devops2](https://github.com/leangsengk90/terraform-devops2)  
📧 **Contact**: Available for DevOps consulting and infrastructure design

---

## � Version History

### Version 2.0 (Current) - October 2025

- ✨ **NEW**: Complete Docker builds system with sample applications
- ✨ **NEW**: ECR authentication automation and token refresh
- ✨ **NEW**: Local development environment with Docker Compose
- ✨ **NEW**: 67-page comprehensive technical documentation
- 🔧 **Enhanced**: User data scripts with automatic ECR login
- 🔧 **Enhanced**: CI/CD integration examples and workflows
- 🐛 **Fixed**: ECR authentication issues in Docker Swarm workers
- 📚 **Added**: Detailed troubleshooting and operations guide

### Version 1.0 - October 2025

- 🎯 **Initial**: Complete Terraform infrastructure for Docker Swarm
- 🎯 **Initial**: Multi-AZ VPC with public/private subnets
- 🎯 **Initial**: Application Load Balancer with auto-scaling
- 🎯 **Initial**: ECR repository and IAM role configuration
- 🎯 **Initial**: Automated deployment and cleanup scripts

## �🙏 Acknowledgments

- **AWS** for comprehensive cloud services and Free Tier offerings
- **HashiCorp** for Terraform infrastructure automation
- **Docker** for containerization and Swarm orchestration
- **Open Source Community** for tools and best practices

---

## 🌟 What's Next?

**Planned Enhancements:**

- 🔄 Kubernetes migration path documentation
- 📊 Prometheus & Grafana monitoring stack
- 🔐 Let's Encrypt SSL automation
- 🧪 Integration testing automation
- 📱 Mobile-friendly status dashboard

**Contributing:**
Feel free to open issues or submit pull requests for improvements!

---

**Last Updated**: October 18, 2025  
**Version**: 2.0  
**Status**: ✅ Production Ready
