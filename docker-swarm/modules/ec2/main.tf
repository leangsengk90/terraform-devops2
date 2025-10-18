# Generate TLS private key for SSH access
resource "tls_private_key" "swarm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key Pair for EC2 instances
resource "aws_key_pair" "swarm_key" {
  key_name   = "${var.project_name}-swarm-key"
  public_key = file("~/.ssh/docker-swarm-key.pub")

  tags = var.tags
}

# User data script for Docker Swarm Master
locals {
  master_user_data = base64encode(templatefile("${path.module}/user_data/master.sh", {
    ecr_repository_url = var.ecr_repository_url
    region            = var.aws_region
  }))

  worker_user_data = base64encode(templatefile("${path.module}/user_data/worker.sh", {
    ecr_repository_url = var.ecr_repository_url
    region            = var.aws_region
  }))
}

# Launch Template for Swarm Master
# Docker Swarm Master Instance
resource "aws_instance" "swarm_master" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.master_instance_type
  key_name                    = aws_key_pair.swarm_key.key_name
  vpc_security_group_ids      = [var.master_security_group_id]
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true
  iam_instance_profile        = var.iam_instance_profile_name
  user_data                   = local.master_user_data
  
  # Enable detailed monitoring and faster termination
  monitoring                     = true
  disable_api_termination        = false
  instance_initiated_shutdown_behavior = "terminate"

  tags = merge(var.tags, {
    Name = "${var.project_name}-swarm-master"
    Role = "master"
  })
}

# Launch Template for Swarm Workers
resource "aws_launch_template" "swarm_worker" {
  name_prefix   = "${var.project_name}-worker-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.worker_instance_type
  key_name      = aws_key_pair.swarm_key.key_name

  vpc_security_group_ids = [var.worker_security_group_id]
  
  # Enable faster termination for workers
  disable_api_termination = false
  instance_initiated_shutdown_behavior = "terminate"
  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  user_data = local.worker_user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_name}-swarm-worker"
      Role = "worker"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for Workers
resource "aws_autoscaling_group" "swarm_workers" {
  name                = "${var.project_name}-swarm-workers"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = var.target_group_arns
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.worker_min_size
  max_size         = var.worker_max_size
  desired_capacity = var.worker_desired_capacity

  # Enable force delete and reduce wait times for faster destroy
  force_delete         = true
  wait_for_capacity_timeout = "5m"
  
  launch_template {
    id      = aws_launch_template.swarm_worker.id
    version = "$Latest"
  }

  # Lifecycle configuration for reliable destroy
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-swarm-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Wait for master to be ready before creating workers
  depends_on = [aws_instance.swarm_master]
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.swarm_workers.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.swarm_workers.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.swarm_workers.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.swarm_workers.name
  }

  tags = var.tags
}