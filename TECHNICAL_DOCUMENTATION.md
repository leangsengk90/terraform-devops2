# Docker Swarm Infrastructure on AWS

## Comprehensive Technical Documentation

---

**Document Version:** 1.0  
**Last Updated:** October 18, 2025  
**Author:** DevOps Team Group 4  
**Project:** Production Docker Swarm Infrastructure

---

## Executive Summary

This document provides comprehensive technical documentation for a production-ready Docker Swarm infrastructure deployed on Amazon Web Services (AWS). The infrastructure implements a highly available, scalable, and secure container orchestration platform using Infrastructure as Code (IaC) principles with Terraform.

### Key Achievements

- **Multi-tier Security Architecture**: Private subnets for worker nodes with NAT Gateway routing
- **Auto-scaling Capabilities**: Dynamic worker node scaling based on CPU utilization (2-6 instances)
- **High Availability**: Multi-AZ deployment with Application Load Balancer
- **Secure Container Registry**: AWS ECR integration with automated lifecycle policies
- **Comprehensive Monitoring**: CloudWatch integration for metrics, logs, and alarms
- **Automated Deployment**: One-click infrastructure provisioning and teardown

---

## 1. Architecture Overview

### 1.1 Infrastructure Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                     │  │
│  │                                                           │  │
│  │  ┌─────────────────┐    ┌─────────────────┐              │  │
│  │  │   AZ-1a         │    │   AZ-1b         │              │  │
│  │  │                 │    │                 │              │  │
│  │  │ ┌─────────────┐ │    │ ┌─────────────┐ │              │  │
│  │  │ │Public Subnet│ │    │ │Public Subnet│ │              │  │
│  │  │ │10.0.1.0/24  │ │    │ │10.0.2.0/24  │ │              │  │
│  │  │ │   ALB       │ │    │ │ NAT Gateway │ │              │  │
│  │  │ │Swarm Master │ │    │ │             │ │              │  │
│  │  │ └─────────────┘ │    │ └─────────────┘ │              │  │
│  │  │                 │    │                 │              │  │
│  │  │ ┌─────────────┐ │    │ ┌─────────────┐ │              │  │
│  │  │ │Private Subnet│ │   │ │Private Subnet│ │              │  │
│  │  │ │10.0.3.0/24  │ │    │ │10.0.4.0/24  │ │              │  │
│  │  │ │Swarm Workers│ │    │ │Swarm Workers│ │              │  │
│  │  │ │   (Auto     │ │    │ │   (Auto     │ │              │  │
│  │  │ │  Scaling)   │ │    │ │  Scaling)   │ │              │  │
│  │  │ └─────────────┘ │    │ └─────────────┘ │              │  │
│  │  └─────────────────┘    └─────────────────┘              │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Managed Services                       │  │
│  │  ┌─────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐  │  │
│  │  │   ECR   │ │    S3       │ │  DynamoDB   │ │ Systems │  │  │
│  │  │Container│ │Terraform    │ │   State     │ │Manager  │  │  │
│  │  │Registry │ │   State     │ │   Locking   │ │Parameter│  │  │
│  │  │         │ │             │ │             │ │  Store  │  │  │
│  │  └─────────┘ └─────────────┘ └─────────────┘ └─────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Architecture

The infrastructure is organized into four distinct layers:

1. **Bootstrap Layer**: Foundation for state management
2. **Network Layer**: VPC, subnets, and routing
3. **Orchestration Layer**: Docker Swarm cluster with supporting services
4. **Application Layer**: Containerized service deployment

---

## 2. Infrastructure Components

### 2.1 Bootstrap Infrastructure (`bootstrap/`)

#### Purpose

Establishes the foundational AWS resources required for secure Terraform state management across the entire infrastructure stack.

#### Components

**S3 Bucket for State Storage**

- **Name**: `devops-group4-prod`
- **Features**:
  - Versioning enabled for state history
  - Server-side encryption (AES256)
  - Public access blocked
  - Force destroy enabled for cleanup

**DynamoDB Table for State Locking**

- **Name**: `terraform-locks`
- **Configuration**:
  - Pay-per-request billing
  - Hash key: `LockID` (String)
  - Prevents concurrent Terraform operations

#### Security Features

```hcl
# Comprehensive public access blocking
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

### 2.2 Network Infrastructure (`vpc/`)

#### VPC Configuration

- **CIDR Block**: `10.0.0.0/16` (65,536 IP addresses)
- **Region**: `ap-southeast-1` (Singapore)
- **DNS Support**: Enabled
- **DNS Hostnames**: Enabled

#### Subnet Architecture

**Public Subnets**

- `10.0.1.0/24` (AZ-1a): ALB, Swarm Master, NAT Gateway
- `10.0.2.0/24` (AZ-1b): High availability components

**Private Subnets**

- `10.0.3.0/24` (AZ-1a): Swarm worker nodes
- `10.0.4.0/24` (AZ-1b): Swarm worker nodes

#### Routing Configuration

**Public Route Table**

- Default route: `0.0.0.0/0` → Internet Gateway
- Purpose: Internet access for public resources

**Private Route Tables (per AZ)**

- Default route: `0.0.0.0/0` → NAT Gateway
- Purpose: Secure internet access for private resources

### 2.3 Docker Swarm Infrastructure (`docker-swarm/`)

#### Master Node Configuration

- **Instance Type**: t2.micro
- **Placement**: Public subnet (AZ-1a)
- **Responsibilities**:
  - Swarm cluster initialization
  - Service orchestration
  - Worker token management
  - Systems Manager parameter updates

#### Worker Node Configuration

- **Instance Type**: t2.micro
- **Placement**: Private subnets (Multi-AZ)
- **Auto Scaling Group**:
  - Minimum: 2 instances
  - Maximum: 6 instances
  - Desired: 2 instances
- **Scaling Triggers**:
  - Scale up: CPU > 70% for 2 evaluation periods
  - Scale down: CPU < 30% for 2 evaluation periods

---

## 3. Security Architecture

### 3.1 Network Security

#### Security Groups

**ALB Security Group**

- **Inbound**:
  - Port 80 (HTTP): `0.0.0.0/0`
  - Port 443 (HTTPS): `0.0.0.0/0`
- **Outbound**: All traffic allowed

**Swarm Master Security Group**

- **Inbound**:
  - Port 22 (SSH): `0.0.0.0/0` (Consider restricting to specific IPs)
  - Port 2377 (Swarm Management): VPC only (`10.0.0.0/16`)
  - Port 7946 (Overlay Network): VPC only (TCP/UDP)
  - Port 4789 (VXLAN): VPC only (UDP)
  - Ports 8000-8999 (Applications): From ALB only
- **Outbound**: All traffic allowed

**Swarm Worker Security Group**

- **Inbound**:
  - Port 22 (SSH): From Master only
  - Port 2377 (Swarm Management): From Master only
  - Port 7946 (Overlay Network): VPC only (TCP/UDP)
  - Port 4789 (VXLAN): VPC only (UDP)
  - Ports 8000-8999 (Applications): From ALB only
- **Outbound**: All traffic allowed

### 3.2 Identity and Access Management (IAM)

#### EC2 Instance Role Permissions

**ECR Access Policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages"
      ],
      "Resource": "*"
    }
  ]
}
```

**CloudWatch Logs Policy**

- Log group creation and management
- Log stream creation and management
- Log event publishing

**Systems Manager Policy**

- Session Manager access (secure shell alternative)
- Parameter Store access for Docker Swarm tokens
- Instance information updates

### 3.3 Container Registry Security

#### ECR Repository Configuration

- **Image Scanning**: Enabled on push
- **Encryption**: AES256
- **Tag Mutability**: MUTABLE (allows image updates)

#### Lifecycle Management

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Delete untagged images older than 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

---

## 4. High Availability and Scalability

### 4.1 Load Balancing

#### Application Load Balancer (ALB)

- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Subnets**: Multi-AZ public subnets
- **Health Checks**:
  - Protocol: HTTP
  - Path: `/health` (configurable per service)
  - Healthy threshold: 2 consecutive successes
  - Unhealthy threshold: 2 consecutive failures
  - Timeout: 5 seconds
  - Interval: 30 seconds

#### Target Groups

- **Default Target Group**: Basic health checking
- **Service-specific Target Groups**: Per-service configuration
  - App service: Port 8080, path pattern `/*`

### 4.2 Auto Scaling Configuration

#### Scaling Policies

```hcl
# Scale Up Policy
resource "aws_autoscaling_policy" "scale_up" {
  scaling_adjustment = 1
  adjustment_type    = "ChangeInCapacity"
  cooldown          = 300  # 5 minutes
}

# Scale Down Policy
resource "aws_autoscaling_policy" "scale_down" {
  scaling_adjustment = -1
  adjustment_type    = "ChangeInCapacity"
  cooldown          = 300  # 5 minutes
}
```

#### CloudWatch Alarms

- **CPU High**: >70% average over 2 periods (2 minutes)
- **CPU Low**: <30% average over 2 periods (2 minutes)

### 4.3 Fault Tolerance

#### Multi-AZ Deployment

- Resources distributed across `ap-southeast-1a` and `ap-southeast-1b`
- NAT Gateway redundancy for private subnet internet access
- Cross-AZ load balancing

#### Health Check Mechanisms

1. **ELB Health Checks**: Application-level health monitoring
2. **Auto Scaling Health Checks**: Instance-level health monitoring
3. **Docker Swarm Health Checks**: Container-level health monitoring

---

## 5. Monitoring and Observability

### 5.1 CloudWatch Integration

#### Metrics Collection

```json
{
  "metrics": {
    "namespace": "DockerSwarm/Master|Worker",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

#### Log Management

- **Master Logs**: `/aws/ec2/docker-swarm/master`
- **Worker Logs**: `/aws/ec2/docker-swarm/worker`
- **Docker Logs**: Container and swarm service logs
- **Retention**: Configurable (default: indefinite)

### 5.2 Systems Manager Integration

#### Parameter Store Usage

- **Swarm Tokens**: Secure storage and sharing of join tokens
- **Master IP**: Dynamic master node IP sharing
- **Configuration**: Environment-specific parameters

#### Session Manager

- Secure shell access without SSH keys
- Audit trail for all sessions
- No inbound security group rules required

---

## 6. Deployment Procedures

### 6.1 Initial Deployment

#### Prerequisites

1. **AWS CLI Configuration**: Valid credentials and region
2. **Terraform Installation**: Version compatible with AWS provider ~> 5.0
3. **SSH Key Pair**: For EC2 instance access

#### Deployment Sequence

```bash
# Execute the complete deployment
./deploy-all.sh
```

**Step-by-step Process:**

1. **Bootstrap Deployment** (`bootstrap/`)

   - Creates S3 bucket for state storage
   - Creates DynamoDB table for state locking
   - Establishes foundation for remote state

2. **VPC Deployment** (`vpc/`)

   - Creates VPC with public and private subnets
   - Configures Internet Gateway and NAT Gateways
   - Establishes routing tables and associations

3. **Docker Swarm Deployment** (`docker-swarm/`)
   - Creates IAM roles and security groups
   - Provisions ECR repository
   - Deploys Application Load Balancer
   - Launches Swarm master instance
   - Creates Auto Scaling Group for workers

### 6.2 Service Deployment

#### Method 1: Terraform-based Deployment (`service-deployment/`)

```bash
# Deploy using Terraform
cd service-deployment
terraform init
terraform apply

# Services defined in variables.tf
services = [
  {
    compose_file = "docker-compose.yml"
    stack_name   = "nginx-stack"
  }
]
```

#### Method 2: Manual Deployment

```bash
# SSH to master node
ssh -i ~/.ssh/docker-swarm-key ec2-user@<MASTER_IP>

# Deploy Docker stack
docker stack deploy -c docker-compose.yml <stack-name>

# Monitor deployment
docker service ls
docker service ps <service-name>
```

#### Method 3: ECR-based Deployment

```bash
# Login to ECR
aws ecr get-login-password --region ap-southeast-1 | \
    docker login --username AWS --password-stdin <ECR_URL>

# Tag and push image
docker tag your-app:latest <ECR_URL>:latest
docker push <ECR_URL>:latest

# Deploy from ECR
docker service create \
    --name your-app \
    --replicas 3 \
    --publish 8080:80 \
    <ECR_URL>:latest
```

### 6.3 Infrastructure Teardown

#### Complete Cleanup

```bash
# Execute complete teardown
./cleanup-all.sh
```

**Teardown Sequence:**

1. Service deployments (if deployed via Terraform)
2. Docker Swarm infrastructure
3. VPC infrastructure
4. Bootstrap infrastructure

#### Safe Teardown Features

- **Auto Scaling Group Pre-scaling**: Forces ASG to 0 capacity
- **Retry Logic**: Multiple attempts for resource cleanup
- **Dependency Handling**: Proper resource destruction order
- **Error Tolerance**: Continues cleanup despite individual failures

---

## 7. Operations and Maintenance

### 7.1 Scaling Operations

#### Manual Scaling

```bash
# Scale specific service
docker service scale nginx=5

# Scale Auto Scaling Group
aws autoscaling set-desired-capacity \
    --auto-scaling-group-name docker-swarm-swarm-workers \
    --desired-capacity 4
```

#### Automated Scaling

- **Triggers**: CPU utilization thresholds
- **Cooldown**: 5 minutes between scaling actions
- **Limits**: 2-6 worker instances

### 7.2 Maintenance Procedures

#### Rolling Updates

```bash
# Update service with zero downtime
docker service update \
    --image <new-image>:latest \
    --update-parallelism 1 \
    --update-delay 10s \
    <service-name>
```

#### Health Monitoring

```bash
# Check swarm status
docker node ls

# Check service health
docker service ps <service-name>

# View service logs
docker service logs <service-name>
```

#### Infrastructure Updates

1. **Terraform Plan**: Review changes before applying
2. **Staged Deployment**: Update non-production first
3. **Blue-Green Strategy**: Consider for major updates
4. **Rollback Plan**: Maintain previous Terraform state

### 7.3 Backup and Recovery

#### State Backup

- **S3 Versioning**: Automatic Terraform state versioning
- **Cross-Region**: Consider S3 cross-region replication
- **Retention**: Configure lifecycle policies

#### Disaster Recovery

1. **Infrastructure Recreation**: Use Terraform to rebuild
2. **Data Recovery**: Restore from application-specific backups
3. **Network Configuration**: DNS and load balancer updates
4. **Service Health**: Verify all services post-recovery

---

## 8. Security Best Practices

### 8.1 Network Security Recommendations

#### Current Security Posture

✅ **Implemented**:

- Private subnets for worker nodes
- NAT Gateway for secure internet access
- Security groups with minimal required access
- VPC-only communication for swarm management

⚠️ **Recommended Improvements**:

- Restrict SSH access to specific IP ranges
- Implement VPN or bastion host for SSH access
- Consider AWS Session Manager for shell access
- Enable VPC Flow Logs for network monitoring

#### Enhanced SSH Security

```hcl
# Restrict SSH to specific CIDR blocks
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["203.0.113.0/24"]  # Replace with your IP range
}
```

### 8.2 Container Security

#### Image Security

- **Base Images**: Use official, minimal base images
- **Vulnerability Scanning**: ECR scan on push enabled
- **Image Signing**: Consider Docker Content Trust
- **Regular Updates**: Automated dependency updates

#### Runtime Security

- **Non-root Containers**: Run containers as non-root user
- **Resource Limits**: Set CPU and memory constraints
- **Secrets Management**: Use Docker secrets or AWS Secrets Manager
- **Network Policies**: Implement overlay network segmentation

### 8.3 Access Control

#### IAM Best Practices

- **Least Privilege**: Minimal required permissions
- **Role-based Access**: Service-specific IAM roles
- **Regular Audits**: Review and rotate access keys
- **MFA Enforcement**: Multi-factor authentication

#### Container Registry Access

- **ECR Policies**: Resource-based access control
- **Image Signing**: Verify image integrity
- **Access Logging**: CloudTrail for API calls

---

## 9. Troubleshooting Guide

### 9.1 Common Deployment Issues

#### SSH Key Format Error

```bash
# Error: Key is not in valid OpenSSH public key format
# Solution: Generate key in OpenSSH format
ssh-keygen -t rsa -b 4096 -f ~/.ssh/docker-swarm-key -N "" -m OpenSSH
```

#### Terraform State Lock

```bash
# Error: Error locking state
# Solution: Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

#### Auto Scaling Group Destruction

```bash
# Error: ASG has instances and cannot be deleted
# Solution: Scale down before destruction (handled in cleanup-all.sh)
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name <ASG_NAME> \
    --min-size 0 --max-size 0 --desired-capacity 0
```

### 9.2 Service Issues

#### Swarm Node Not Joining

```bash
# Check master node status
docker node ls

# Verify token in Systems Manager
aws ssm get-parameter --name "/docker-swarm/worker-token" --with-decryption

# Manual join (on worker)
docker swarm join --token <WORKER_TOKEN> <MASTER_IP>:2377
```

#### Service Not Starting

```bash
# Check service status
docker service ps <service-name> --no-trunc

# View service logs
docker service logs <service-name>

# Check node capacity
docker node ls
docker system df
```

#### Load Balancer Health Checks Failing

```bash
# Verify target group health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# Check security group rules
aws ec2 describe-security-groups --group-ids <SG_ID>

# Test health check endpoint
curl -v http://<INSTANCE_IP>:8080/health
```

### 9.3 Performance Issues

#### High CPU Utilization

1. **Check Service Distribution**: Ensure even load distribution
2. **Scale Services**: Increase replica count
3. **Resource Limits**: Review container resource constraints
4. **Auto Scaling**: Verify scaling policies are working

#### Memory Issues

1. **Monitor Usage**: CloudWatch memory metrics
2. **Container Limits**: Set appropriate memory limits
3. **Garbage Collection**: Application-level memory management
4. **Instance Types**: Consider larger instance types

---

## 10. Cost Optimization

### 10.1 Current Cost Structure

#### Compute Costs

- **Master Node**: 1 × t2.micro (744 hours/month)
- **Worker Nodes**: 2-6 × t2.micro (dynamic scaling)
- **NAT Gateway**: 2 × NAT Gateway (multi-AZ)

#### Storage Costs

- **ECR**: Image storage and data transfer
- **S3**: Terraform state storage (minimal)
- **CloudWatch Logs**: Log storage and retention

#### Network Costs

- **Load Balancer**: ALB hourly charges and LCU costs
- **Data Transfer**: Internet and inter-AZ transfer

### 10.2 Optimization Strategies

#### Right-sizing Instances

```hcl
# Use smaller instances for development
variable "master_instance_type" {
  default = "t3.nano"  # Cost-effective for low traffic
}

variable "worker_instance_type" {
  default = "t3.micro"  # Burstable performance
}
```

#### Scheduled Scaling

```bash
# Scale down during off-hours
aws autoscaling put-scheduled-update-group-action \
    --auto-scaling-group-name docker-swarm-swarm-workers \
    --scheduled-action-name "scale-down-evening" \
    --recurrence "0 18 * * MON-FRI" \
    --desired-capacity 1 \
    --min-size 1 \
    --max-size 1
```

#### Reserved Capacity

- **Reserved Instances**: 1-3 year commitments for predictable workloads
- **Spot Instances**: Consider for worker nodes (requires fault tolerance)
- **Savings Plans**: Compute-based savings plans

---

## 11. Compliance and Governance

### 11.1 Tagging Strategy

#### Mandatory Tags

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "DevOps-Team"
    CostCenter  = "IT-Infrastructure"
    Backup      = "Required"
  }
}
```

### 11.2 Change Management

#### Infrastructure Changes

1. **Version Control**: All changes via Git
2. **Code Review**: Pull request approval required
3. **Testing**: Validate in development environment
4. **Documentation**: Update this document for changes
5. **Rollback Plan**: Maintain previous working state

#### Emergency Procedures

1. **Incident Response**: Defined escalation procedures
2. **Communication Plan**: Stakeholder notification
3. **Recovery Steps**: Documented disaster recovery
4. **Post-mortem**: Analysis and improvement actions

---

## 12. Future Enhancements

### 12.1 Short-term Improvements (1-3 months)

#### Security Enhancements

- [ ] Implement AWS WAF for application protection
- [ ] Enable GuardDuty for threat detection
- [ ] Set up AWS Config for compliance monitoring
- [ ] Implement AWS Secrets Manager for sensitive data

#### Operational Improvements

- [ ] Set up centralized logging with ELK stack
- [ ] Implement Prometheus and Grafana monitoring
- [ ] Create automated backup procedures
- [ ] Establish disaster recovery testing

### 12.2 Medium-term Goals (3-6 months)

#### Platform Enhancements

- [ ] Multi-region deployment capability
- [ ] Blue-green deployment automation
- [ ] Container image vulnerability management
- [ ] Service mesh implementation (Istio/Linkerd)

#### DevOps Integration

- [ ] CI/CD pipeline integration
- [ ] Automated testing frameworks
- [ ] Infrastructure testing (Terratest)
- [ ] Performance testing automation

### 12.3 Long-term Vision (6-12 months)

#### Cloud-Native Evolution

- [ ] Migration to Amazon EKS (Kubernetes)
- [ ] Serverless components integration
- [ ] Multi-cloud strategy evaluation
- [ ] GitOps implementation (ArgoCD/Flux)

#### Advanced Features

- [ ] Machine learning-based auto-scaling
- [ ] Predictive failure analysis
- [ ] Automated security remediation
- [ ] Cost optimization automation

---

## 13. Conclusion

This Docker Swarm infrastructure represents a robust, scalable, and secure foundation for containerized applications on AWS. The implementation demonstrates Infrastructure as Code best practices while providing production-ready features including:

- **Security**: Multi-layered security with network isolation and IAM controls
- **Scalability**: Auto-scaling capabilities with load balancing
- **Reliability**: Multi-AZ deployment with comprehensive health monitoring
- **Operability**: Automated deployment and comprehensive monitoring
- **Maintainability**: Modular Terraform structure with clear documentation

The infrastructure successfully addresses key operational requirements while maintaining flexibility for future enhancements and scaling needs.

---

## Appendices

### Appendix A: Configuration Files Summary

| Component | File Path                        | Purpose                      |
| --------- | -------------------------------- | ---------------------------- |
| Bootstrap | `bootstrap/main.tf`              | S3 bucket and DynamoDB table |
| VPC       | `vpc/main.tf`                    | Network infrastructure       |
| Security  | `docker-swarm/modules/security/` | Security groups              |
| IAM       | `docker-swarm/modules/iam/`      | Roles and policies           |
| ECR       | `docker-swarm/modules/ecr/`      | Container registry           |
| ALB       | `docker-swarm/modules/alb/`      | Load balancer                |
| EC2       | `docker-swarm/modules/ec2/`      | Compute instances            |
| Deploy    | `deploy-all.sh`                  | Deployment automation        |
| Cleanup   | `cleanup-all.sh`                 | Teardown automation          |

### Appendix B: Default Variables

```hcl
# Project Configuration
project_name = "docker-swarm"
environment  = "production"
aws_region   = "ap-southeast-1"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

# Instance Configuration
master_instance_type = "t2.micro"
worker_instance_type = "t2.micro"

# Auto Scaling Configuration
worker_min_size         = 2
worker_max_size         = 6
worker_desired_capacity = 2

# Security Configuration
allowed_ssh_cidrs = ["10.0.0.0/16"]
```

### Appendix C: Useful Commands Reference

```bash
# Infrastructure Management
./deploy-all.sh                    # Deploy complete infrastructure
./cleanup-all.sh                   # Teardown complete infrastructure
terraform plan                     # Review planned changes
terraform apply                    # Apply infrastructure changes

# Docker Swarm Management
docker node ls                     # List swarm nodes
docker service ls                  # List running services
docker service ps <service>        # Show service tasks
docker service logs <service>      # View service logs
docker service scale <service>=N   # Scale service to N replicas

# AWS CLI Commands
aws elbv2 describe-load-balancers  # List load balancers
aws autoscaling describe-auto-scaling-groups  # List ASGs
aws ecr describe-repositories      # List ECR repositories
aws ssm get-parameter --name "/docker-swarm/worker-token"  # Get swarm token

# Monitoring Commands
aws logs describe-log-groups       # List CloudWatch log groups
aws cloudwatch get-metric-statistics  # Get metrics data
```

---

**Document Control**  
**Classification:** Internal Use  
**Distribution:** DevOps Team, Infrastructure Team, Security Team  
**Next Review Date:** January 18, 2026

---
