# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })
}

# Default Target Group for health checks
resource "aws_lb_target_group" "default" {
  name     = "${var.project_name}-default-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-default-tg"
  })
}

# Target Groups for different services (flexible deployment)
resource "aws_lb_target_group" "services" {
  count = length(var.service_configs)
  
  name     = "${var.project_name}-${var.service_configs[count.index].name}-tg"
  port     = var.service_configs[count.index].port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = var.service_configs[count.index].health_check_matcher
    path                = var.service_configs[count.index].health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.service_configs[count.index].name}-tg"
    Service = var.service_configs[count.index].name
  })
}

# ALB Listener - HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - return fixed response
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Docker Swarm ALB - No matching service found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

# Listener Rules for each service
resource "aws_lb_listener_rule" "service_rules" {
  count = length(var.service_configs)
  
  listener_arn = aws_lb_listener.http.arn
  priority     = 100 + count.index

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[count.index].arn
  }

  condition {
    path_pattern {
      values = var.service_configs[count.index].path_patterns
    }
  }

  # Optional: Host-based routing
  dynamic "condition" {
    for_each = var.service_configs[count.index].host_headers != null ? [1] : []
    content {
      host_header {
        values = var.service_configs[count.index].host_headers
      }
    }
  }

  tags = merge(var.tags, {
    Service = var.service_configs[count.index].name
  })
}

# Optional HTTPS Listener (if SSL certificate is provided)
resource "aws_lb_listener" "https" {
  count = var.ssl_certificate_arn != null ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  # Default action - return fixed response
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Docker Swarm ALB - No matching service found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

# HTTPS Listener Rules for each service
resource "aws_lb_listener_rule" "service_rules_https" {
  count = var.ssl_certificate_arn != null ? length(var.service_configs) : 0
  
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100 + count.index

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[count.index].arn
  }

  condition {
    path_pattern {
      values = var.service_configs[count.index].path_patterns
    }
  }

  # Optional: Host-based routing
  dynamic "condition" {
    for_each = var.service_configs[count.index].host_headers != null ? [1] : []
    content {
      host_header {
        values = var.service_configs[count.index].host_headers
      }
    }
  }

  tags = merge(var.tags, {
    Service = var.service_configs[count.index].name
  })
}