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

# Wait for master to be ready and get join token from AWS Systems Manager
RETRIES=0
MAX_RETRIES=30

while [ $RETRIES -lt $MAX_RETRIES ]; do
    echo "Attempting to join swarm (attempt $((RETRIES + 1))/$MAX_RETRIES)..."
    
    # Get worker token from AWS Systems Manager Parameter Store
    WORKER_TOKEN=$(aws ssm get-parameter --name "/docker-swarm/worker-token" --region ${region} --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)
    MASTER_IP=$(aws ssm get-parameter --name "/docker-swarm/master-ip" --region ${region} --query 'Parameter.Value' --output text 2>/dev/null)
    
    if [ ! -z "$WORKER_TOKEN" ] && [ ! -z "$MASTER_IP" ] && [ "$WORKER_TOKEN" != "placeholder" ]; then
        echo "Got worker token and master IP from SSM, joining swarm..."
        docker swarm join --token $WORKER_TOKEN $MASTER_IP:2377
        if [ $? -eq 0 ]; then
            echo "Successfully joined swarm"
            # Store successful join in CloudWatch logs
            aws logs create-log-group --log-group-name "/aws/ec2/docker-swarm/worker" --region ${region} 2>/dev/null || true
            aws logs put-log-events --log-group-name "/aws/ec2/docker-swarm/worker" --log-stream-name "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --log-events timestamp=$(date +%s)000,message="Worker node successfully joined swarm" --region ${region} 2>/dev/null || true
            break
        fi
    else
        echo "Waiting for master to initialize and store token in SSM..."
    fi
    
    RETRIES=$((RETRIES + 1))
    sleep 30
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    echo "Failed to join swarm after $MAX_RETRIES attempts"
    # Log failure
    aws logs create-log-group --log-group-name "/aws/ec2/docker-swarm/worker" --region ${region} 2>/dev/null || true
    aws logs put-log-events --log-group-name "/aws/ec2/docker-swarm/worker" --log-stream-name "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --log-events timestamp=$(date +%s)000,message="Failed to join swarm after $MAX_RETRIES attempts" --region ${region} 2>/dev/null || true
    exit 1
fi

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "DockerSwarm/Worker",
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
                        "log_group_name": "/aws/ec2/docker-swarm/worker",
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

echo "Docker Swarm Worker setup completed" > /var/log/swarm-setup.log