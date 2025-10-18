#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure Docker to use ECR
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${ecr_repository_url}

# Create ECR login script for periodic authentication
cat > /opt/ecr-login.sh << 'EOF'
#!/bin/bash
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${ecr_repository_url}
echo "$(date): ECR login completed" >> /var/log/ecr-login.log
EOF

chmod +x /opt/ecr-login.sh

# Add cron job to refresh ECR login every 6 hours (ECR tokens expire after 12 hours)
echo "0 */6 * * * root /opt/ecr-login.sh" >> /etc/crontab

# Restart cron service
systemctl restart crond

# Create swarm token file directory
mkdir -p /opt/swarm

# Initialize Docker Swarm
MASTER_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
docker swarm init --advertise-addr $MASTER_IP

# Save swarm join tokens
docker swarm join-token worker -q > /opt/swarm/worker-token
docker swarm join-token manager -q > /opt/swarm/manager-token

# Save master IP
echo $MASTER_IP > /opt/swarm/master-ip

# Store worker token in AWS Systems Manager Parameter Store for secure sharing
WORKER_TOKEN=$(docker swarm join-token worker -q)
aws ssm put-parameter \
    --name "/docker-swarm/worker-token" \
    --description "Docker Swarm worker join token" \
    --value "$WORKER_TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region ${region}

# Store master IP in SSM for workers to discover
aws ssm put-parameter \
    --name "/docker-swarm/master-ip" \
    --description "Docker Swarm master IP address" \
    --value "$MASTER_IP" \
    --type "String" \
    --overwrite \
    --region ${region}

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "DockerSwarm/Master",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/docker",
                        "log_group_name": "/aws/ec2/docker-swarm/master",
                        "log_stream_name": "{instance_id}/docker.log"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Create deployment script
# cat > /opt/swarm/deploy-service.sh << 'EOF'
# #!/bin/bash

# SERVICE_NAME=$$1
# IMAGE_TAG=$$2
# PORT=$$3
# REPLICAS=$${4:-2}

# if [ -z "$$SERVICE_NAME" ] || [ -z "$$IMAGE_TAG" ] || [ -z "$$PORT" ]; then
#     echo "Usage: $$0 <service_name> <image_tag> <port> [replicas]"
#     exit 1
# fi

# # Login to ECR
# aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${ecr_repository_url}

# # Deploy or update service
# docker service create \
#     --name $$SERVICE_NAME \
#     --replicas $$REPLICAS \
#     --publish published=$$PORT,target=$$PORT \
#     --update-parallelism 1 \
#     --update-delay 10s \
#     --restart-condition on-failure \
#     ${ecr_repository_url}:$$IMAGE_TAG || \
# docker service update \
#     --image ${ecr_repository_url}:$$IMAGE_TAG \
#     $$SERVICE_NAME

# echo "Service $$SERVICE_NAME deployed/updated successfully"
# EOF

# chmod +x /opt/swarm/deploy-service.sh

# Signal that the instance is ready
/opt/aws/bin/cfn-signal -e $$? --stack $${AWS::StackName} --resource AutoScalingGroup --region $${AWS::Region} || true

echo "Docker Swarm Master setup completed" > /var/log/swarm-setup.log