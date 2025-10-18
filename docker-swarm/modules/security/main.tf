# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

# Security Group for Docker Swarm Master
resource "aws_security_group" "swarm_master_sg" {
  name        = "${var.project_name}-swarm-master-sg"
  description = "Security group for Docker Swarm Master"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Docker Swarm management port
  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Docker Swarm management"
  }

  # Docker overlay network
  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Docker overlay network TCP"
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Docker overlay network UDP"
  }

  # VXLAN overlay network
  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "VXLAN overlay network"
  }

  # Application ports from ALB
  ingress {
    from_port       = 8000
    to_port         = 8999
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Application ports from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-swarm-master-sg"
  })
}

# Security Group for Docker Swarm Workers
resource "aws_security_group" "swarm_worker_sg" {
  name        = "${var.project_name}-swarm-worker-sg"
  description = "Security group for Docker Swarm Workers"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Docker overlay network
  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Docker overlay network TCP"
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Docker overlay network UDP"
  }

  # VXLAN overlay network
  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "VXLAN overlay network"
  }

  # Application ports from ALB
  ingress {
    from_port       = 8000
    to_port         = 8999
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Application ports from ALB"
  }

  # Worker to worker communication
  ingress {
    from_port = 7946
    to_port   = 7946
    protocol  = "tcp"
    self      = true
    description = "Worker to worker TCP"
  }

  ingress {
    from_port = 7946
    to_port   = 7946
    protocol  = "udp"
    self      = true
    description = "Worker to worker UDP"
  }

  ingress {
    from_port = 4789
    to_port   = 4789
    protocol  = "udp"
    self      = true
    description = "Worker to worker VXLAN"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-swarm-worker-sg"
  })
}